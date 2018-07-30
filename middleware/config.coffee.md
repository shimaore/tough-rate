    PouchDB = require 'ccnq4-pouchdb'
    assert = require 'assert'
    nimble = require 'nimble-direction'
    GatewayManager = require '../gateway_manager'
    pkg = require '../package.json'

    @name = "#{pkg.name}:middleware:config"
    @config = ->
      cfg = @cfg
      @debug "Configuring #{pkg.name} version #{pkg.version}."
      assert cfg.prefix_source?, 'Missing prefix_source'
      assert cfg.sip_domain_name?, 'Missing sip_domain_name'

Configure CouchDB
=================

      await nimble cfg

Push the GatewayManager design document to the local provisioning database
--------------------------------------------------------------------------

      @debug "Updating GatewayManager design document."
      await cfg
        .push GatewayManager.couch
        .catch (error) =>
          @debug "Inserting GatewayManager couchapp failed."

We do not throw, the error might be a 509, in which case it means another process took care of it.

Push the `tough-rate` design document to the master provisioning database
-------------------------------------------------------------------------

      await cfg.reject_tombstones(cfg.prov).catch (error) =>
        @debug 'Reject tombstones failed (ignored)', error.stack ? JSON.stringify error
      await cfg.reject_types(cfg.prov).catch (error) =>
        @debug 'Reject types failed (ignored)', error.stack ? JSON.stringify error

      unless await cfg.replicate 'provisioning'
        throw new Error "Unable to start replication of the provisioning database."

      source = new PouchDB "#{cfg.prefix_source}/provisioning"
      @debug "Querying for rulesets on master database."
      {rows} = await source.allDocs
        startkey: "ruleset:#{cfg.sip_domain_name}:"
        endkey: "ruleset:#{cfg.sip_domain_name};"
        include_docs: true

      for row in rows when row.doc?.database?
        @debug "Going to replicate #{row.doc.database}"
        unless await cfg.replicate row.doc.database
          throw new Error "Unable to start replication of #{row.doc.database} database."

      @debug "Configured."
