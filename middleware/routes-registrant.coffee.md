Registrant plugin
=================

This plugin provides `registrant_host` as a gateway.

    registrant_fields =
      registrant_password:    'X-CCNQ3-Registrant-Password'
      registrant_username:    'X-CCNQ3-Registrant-Username'
      registrant_realm:       'X-CCNQ3-Registrant-Realm'
      registrant_remote_ipv4: 'X-CCNQ3-Registrant-Target'
      registrant_socket:      'X-CCNQ3-Registrant-HostPort'

    update = (entry,ref) ->
      return entry unless entry.source_registrant? and entry.source_registrant is true

      ref.then (source_doc) ->
        result = []
        address = source_doc.registrant_host
        if address?
          if 'string' isnt typeof address
            address = address[0]
          address = "#{address}:5070" unless address.match /:/
          gateway = {address}
          gateway.headers ?= {}
          for field, header of registrant_fields
            gateway.headers[header] = source_doc[field] if source_doc[field]?
          result.push gateway
        result

    plugin = (provisioning) ->
      assert provisioning?, 'Missing provisioning'

      middleware = ->
        return if @finalized()
        ref = provisioning.get "number:#{@source}"
        promise_all @res.gateways, (x) -> update x, ref
        .then (gws) =>
          @res.gateways = gws

    plugin.title = 'Registrant router plugin'
    plugin.description = "A router plugin that injects the source's `registrant_host` as a gateway."
    module.exports = plugin

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
