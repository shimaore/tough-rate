    PouchDB = require 'pouchdb'
    assert = require 'assert'
    nimble = require 'nimble-direction'
    GatewayManager = require '../gateway_manager'
    {couch} = require '../couch'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:middleware:config"
    assert couch?, 'Missing design document'

    seem = require 'seem'

    @name = "#{pkg.name}:middleware:config"
    @config = seem ->
      cfg = @cfg
      debug "Configuring #{pkg.name} version #{pkg.version}.", cfg
      assert cfg.prefix_source?, 'Missing prefix_source'
      assert cfg.sip_domain_name?, 'Missing sip_domain_name'

Configure CouchDB
=================

      yield nimble cfg

Create a local `tough-rate` user
--------------------------------

At this point it's unclear what this user is used for / supposed to do.

      debug "Querying user 'tough-rate'."
      doc = yield cfg.users
        .get 'org.couchdb.user:tough-rate'
        .catch (error) ->
          debug error
          debug '(ignored)'
          {}

      debug "Updating user 'tough-rate'."
      doc._id ?= "org.couchdb.user:tough-rate"
      doc.name ?= 'tough-rate'
      doc.type ?= 'user'
      doc.password = 'tough-rate-password'
      doc.roles = ['provisioning_reader']
      yield cfg.users
        .put doc
        .catch (error) ->
          debug error
          debug "User creation failed."
          throw error

Push the GatewayManager design document to the local provisioning database
--------------------------------------------------------------------------

      debug "Updating GatewayManager design document to version #{couch.version}."
      yield cfg
        .push GatewayManager.couch
        .catch (error) ->
          debug "Inserting GatewayManager couchapp failed."
          throw error

Push the `tough-rate` design document to the master provisioning database
-------------------------------------------------------------------------

      yield cfg
        .master_push couch
        .catch (error) ->
          debug "Inserting Master couchapp failed."
          throw error

      yield cfg.reject_tombstones cfg.prov

      yield cfg.replicate 'provisioning', (doc) ->
        debug "Using replication filter #{couch.replication_filter}"
        doc.filter = couch.replication_filter
        doc.comment += " for #{pkg.name}"

      source = new PouchDB "#{cfg.prefix_source}/provisioning"
      debug "Querying for rulesets on master database."
      {rows} = yield source.allDocs
        startkey: "ruleset:#{cfg.sip_domain_name}:"
        endkey: "ruleset:#{cfg.sip_domain_name};"
        include_docs: true

      debug JSON.stringify rows
      for row in rows when row.doc?.database?
        debug "Going to replicate #{row.doc.database}"
        yield cfg.replicate row.doc.database

      debug "Configured."
