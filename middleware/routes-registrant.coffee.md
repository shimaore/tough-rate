Registrant plugin
=================

This plugin provides `registrant_host` as a gateway.

    registrant_fields =
      registrant_password:    'X-CCNQ3-Registrant-Password'
      registrant_username:    'X-CCNQ3-Registrant-Username'
      registrant_realm:       'X-CCNQ3-Registrant-Realm'
      registrant_remote_ipv4: 'X-CCNQ3-Registrant-Target'
      registrant_socket:      'X-CCNQ3-Registrant-HostPort'

    default_port = 5070

    update = (entry,ref) ->
      unless entry.source_registrant? and entry.source_registrant is true
        debug "Routes Registrant: entry is not source_registrant, skipping", entry
        return entry

      ref
      .then (source_doc) =>
        return if source_doc.disabled

        result = []
        if source_doc.address?
          address = source_doc.address
        else
          address = source_doc.registrant_host
          unless address?
            debug 'No registrant_host for source in a route that requires registrant.', source_doc
            return result

          debug "Routes Registrant: mapping registrant", source_doc
          if 'string' isnt typeof address
            address = address[0]
          address = "#{address}:#{default_port}" unless address.match /:/

        gateway = {address}
        gateway.headers ?= {}
        for field, header of registrant_fields
          gateway.headers[header] = source_doc[field] if source_doc[field]?
        result.push gateway
        result

    build_ref = (provisioning) ->
      debug "Routes Registrant build_ref locating #{@source}."
      provisioning.get "number:#{@source}"

    @name = 'routes-registrant'
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
    @include = ->
      ref_builder = @session.ref_builder ? build_ref
      provisioning = @cfg.prov

      if @res.finalized()
        debug 'Routes Registrant: already finalized.'
        return
      ref = ref_builder.call this, provisioning
      promise_all @res.gateways, (x) => update.call this, x, ref
      .then (gws) =>
        @res.gateways = gws
      .catch (error) =>
        debug "Routes Registrant: #{error}"

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:routes-registrant"
