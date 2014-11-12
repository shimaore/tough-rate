Registrant plugin
=================

This plugin provides `registrant_host` as a gateway.

    plugin = (entry,{source_doc}) ->
      return unless entry.source_registrant? and entry.source_registrant is true
      result = []
      address = source_doc.registrant_host
      if address?
        address = "#{address}:5070" unless address.match /:/
        result.push {address}
      Promise.resolve result

    plugin.title = 'Registrant router plugin'
    plugin.description = "A router plugin that injects the source's `registrant_host` as a gateway."
    module.exports = plugin

Toolbox
-------

    Promise = require 'bluebird'
