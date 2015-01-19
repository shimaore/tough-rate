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
        @logger.info "Routes Registrant: entry is not source_registrant, skipping", entry
        return entry

      ref
      .then (source_doc) =>
        result = []
        if source_doc.address?
          address = source_doc.address
        else
          address = source_doc.registrant_host
          unless address?
            @logger.error 'No registrant_host for source in a route that requires registrant.', source_doc
            return result

          @logger.info "Routes Registrant: mapping registrant", source_doc
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
      @logger.info "Routes Registrant build_ref locating #{@source}."
      provisioning.get "number:#{@source}"

    plugin = ->
      ref_builder = @ref_builder ? build_ref
      provisioning = @options.provisioning
      assert provisioning?, 'Missing provisioning'

      middleware = ->
        if @finalized()
          @logger.info 'Routes Registrant: already finalized.'
          return
        ref = ref_builder.call this, provisioning
        promise_all @res.gateways, (x) => update.call this, x, ref
        .then (gws) =>
          @res.gateways = gws
        .catch (error) =>
          @logger.error "Routes Registrant: #{error}"

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

    plugin.title = 'Registrant router plugin'
    plugin.description = "A router plugin that injects the source's `registrant_host` as a gateway."
    plugin.build_ref = build_ref
    module.exports = plugin

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
    pkg = require '../package.json'
