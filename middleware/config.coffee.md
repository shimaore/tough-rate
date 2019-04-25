    CouchDB = require 'most-couchdb'
    assert = require 'assert'
    Nimble = require 'nimble-direction'
    GatewayManager = require '../gateway_manager'
    pkg = require '../package.json'

    @name = "#{pkg.name}:middleware:config"
    debug = (require 'tangible') @name

    @config = ->
      cfg = @cfg
      debug "Configuring #{pkg.name} version #{pkg.version}."
      assert cfg.prefix_source?, 'Missing prefix_source'
      assert cfg.sip_domain_name?, 'Missing sip_domain_name'

Configure CouchDB
=================

      nimble = await Nimble cfg
      prov = new CouchDB nimble.provisioning

Push the GatewayManager design document to the local provisioning database
--------------------------------------------------------------------------

      debug 'Updating GatewayManager design document.'
      await nimble
        .push GatewayManager.couch
        .catch (error) =>
          debug.dev 'Inserting GatewayManager couchapp failed (ignored).', error.stack ? JSON.stringify error

We do not throw, the error might be a 409, in which case it means another process took care of it.

Push the `tough-rate` design document to the master provisioning database
-------------------------------------------------------------------------

      await nimble.reject_tombstones(prov).catch (error) =>
        debug.dev 'Reject tombstones failed (ignored)', error.stack ? JSON.stringify error
      await cfg.reject_types(prov).catch (error) =>
        debug.dev 'Reject types failed (ignored)', error.stack ? JSON.stringify error

      unless await cfg.replicate 'provisioning'
        throw new Error "Unable to start replication of the provisioning database."

      source = new CouchDB "#{cfg.prefix_source}/provisioning"
      debug "Querying for rulesets on master database."
      rows = source.queryStream null, '_all_docs',
        startkey: "ruleset:#{cfg.sip_domain_name}:"
        endkey: "ruleset:#{cfg.sip_domain_name};"
        include_docs: true

      for await row from rows when row.doc?.database?
        debug "Going to replicate #{row.doc.database}"
        unless await cfg.replicate row.doc.database
          throw new Error "Unable to start replication of #{row.doc.database} database."

      debug "Configured."
