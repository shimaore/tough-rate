    CouchDB = require 'most-couchdb'
    assert = require 'assert'
    Nimble = require 'nimble-direction'
    pkg = require '../package.json'

    @name = "#{pkg.name}:middleware:server"
    {debug} = (require 'tangible') @name
    @web = ->
      @cfg.versions[pkg.name] = pkg.version

    @server_pre = ->
      cfg = @cfg
      assert cfg.sip_domain_name?, 'Missing `sip_domain_name` option.'

      debug "Booting #{pkg.name} #{pkg.version}."

      nimble = Nimble cfg
      prov = new CouchDB nimble.provisioning

`ruleset_of`
------------

Retrieve the ruleset (and ruleset database) for the given ruleset name.

      if cfg.prefix_local?
        {prefix_local} = cfg

        unless prefix_local.match /\/$/
          prefix_local += '/'

        cfg.ruleset_of = (x) =>
          prov.get "ruleset:#{cfg.sip_domain_name}:#{x}"
          .then (doc) =>
            if not doc.database?
              debug "Ruleset #{cfg.sip_domain_name}:#{x} should have a database field."
              return {}

            db = new CouchDB prefix_local + doc.database, true

            data =
              ruleset: doc
              ruleset_database: db

We _must_ return an object, even if an error occurred. The router will detect no data is present and report the problem via SIP.

          .catch (error) =>
            debug "Could not locate information for ruleset #{x} in #{cfg.sip_domain_name}.", error
            {}

      else
        debug "#{pkg.name} #{pkg.version}: no `prefix_local` was present in the configuration, hopefully you won't use rulesets."
        cfg.ruleset_of = =>
          debug "#{pkg.name} #{pkg.version}: `ruleset_of` was called but no `prefix_local` was present in the configuration."
          {}
