    PouchDB = require 'pouchdb'
    assert = require 'assert'
    nimble = require 'nimble-direction'
    LRU = require 'lru-cache'
    pkg = require '../package.json'

    @name = "#{pkg.name}:middleware:server"
    @web = ->
      @cfg.versions[pkg.name] = pkg.version

    @server_pre = ->
      cfg = @cfg
      assert cfg.sip_domain_name?, 'Missing `sip_domain_name` option.'

      @debug "Booting #{pkg.name} #{pkg.version}.", cfg

`ruleset_of`
------------

Retrieve the ruleset (and ruleset database) for the given ruleset name.

      if cfg.prefix_local?

Use a cache since the calls to `ruleset_of()` seem to not release the databases.

        database_cache = LRU cfg.ruleset_database_cache_size ? 100

        cfg.ruleset_of = (x) =>
          cfg.prov.get "ruleset:#{cfg.sip_domain_name}:#{x}"
          .then (doc) ->
            if not doc.database?
              @debug "Ruleset #{cfg.sip_domain_name}:#{x} should have a database field."
              return {}

            db = database_cache.get doc.database
            if not db?
              db = new PouchDB "#{cfg.prefix_local}/#{doc.database}"
              database_cache.set doc.database, db

            data =
              ruleset: doc
              ruleset_database: db

We _must_ return an object, even if an error occurred. The router will detect no data is present and report the problem via SIP.

          .catch (error) =>
            @debug "Could not locate information for ruleset #{x} in #{cfg.sip_domain_name}."
            {}

      else
        @debug "#{pkg.name} #{pkg.version}: no `prefix_local` was present in the configuration, hopefully you won't use rulesets."
        cfg.ruleset_of = =>
          @debug "#{pkg.name} #{pkg.version}: `ruleset_of` was called but no `prefix_local` was present in the configuration."
          {}

      nimble cfg
