    PouchDB = require 'pouchdb-core'
      .plugin require 'pouchdb-adapter-http'
    assert = require 'assert'
    nimble = require 'nimble-direction'
    GatewayManager = require '../gateway_manager'
    pkg = require '../package.json'

    seem = require 'seem'

    @name = "#{pkg.name}:middleware:config"
    @config = seem ->
      cfg = @cfg
      @debug "Configuring #{pkg.name} version #{pkg.version}."
      assert cfg.prefix_source?, 'Missing prefix_source'
      assert cfg.sip_domain_name?, 'Missing sip_domain_name'

Configure CouchDB
=================

      yield nimble cfg

Create a local `tough-rate` user
--------------------------------

At this point it's unclear what this user is used for / supposed to do.

      @debug "Querying user 'tough-rate'."
      doc = yield cfg.users
        .get 'org.couchdb.user:tough-rate'
        .catch (error) =>
          @debug "#{error.stack ? error} (ignored)"
          {}

      @debug "Updating user 'tough-rate'."
      doc._id ?= "org.couchdb.user:tough-rate"
      doc.name ?= 'tough-rate'
      doc.type ?= 'user'
      doc.password = 'tough-rate-password'
      doc.roles = ['provisioning_reader']
      yield cfg.users
        .put doc
        .catch (error) =>
          @debug "User creation failed: #{error.stack ? error}"
          throw error

Push the GatewayManager design document to the local provisioning database
--------------------------------------------------------------------------

      @debug "Updating GatewayManager design document."
      yield cfg
        .push GatewayManager.couch
        .catch (error) =>
          @debug "Inserting GatewayManager couchapp failed."

We do not throw, the error might be a 509, in which case it means another process took care of it.

Push the `tough-rate` design document to the master provisioning database
-------------------------------------------------------------------------

      yield cfg.reject_tombstones cfg.prov

      yield cfg.replicate 'provisioning', (doc) ->
        doc.comment += " for #{pkg.name}"

      source = new PouchDB "#{cfg.prefix_source}/provisioning"
      @debug "Querying for rulesets on master database."
      {rows} = yield source.allDocs
        startkey: "ruleset:#{cfg.sip_domain_name}:"
        endkey: "ruleset:#{cfg.sip_domain_name};"
        include_docs: true

      for row in rows when row.doc?.database?
        @debug "Going to replicate #{row.doc.database}"
        yield cfg.replicate row.doc.database

      @debug "Configured."
