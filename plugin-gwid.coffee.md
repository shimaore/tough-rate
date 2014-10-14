Default `gwid` router plugin
============================

    plugin = (entry) ->
      return unless entry.gwid?
      @gateway_manager.resolve_gateway entry.gwid
    plugin.title = 'Default `gwid` router plugin'
    plugin.description = "Injects the gateway described by the `gwid` into the list of gateways."
    module.exports = plugin
