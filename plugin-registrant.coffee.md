Registrant plugin
=================

This plugin provides `registrant_host` as a gateway.

    registrant_fields = 'registrant_password registrant_username registrant_realm registrant_remote_ipv4 registrant_socket'.split ' '

    plugin = (entry,{source_doc}) ->
      return unless entry.source_registrant? and entry.source_registrant is true
      result = []
      address = source_doc.registrant_host
      if address?
        if 'string' isnt typeof address
          address = address[0]
        address = "#{address}:5070" unless address.match /:/
        gateway = {address}
        for field in registrant_fields
          gateway[field] = source_doc[field] if source_doc[field]?
        result.push gateway
      Promise.resolve result

    plugin.title = 'Registrant router plugin'
    plugin.description = "A router plugin that injects the source's `registrant_host` as a gateway."
    module.exports = plugin

Toolbox
-------

    Promise = require 'bluebird'
