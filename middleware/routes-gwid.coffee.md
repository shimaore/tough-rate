Default `gwid` router plugin
============================

    update = (gateway_manager,entry) ->
      return entry unless entry.gwid?
      gateway_manager.resolve_gateway entry.gwid

    plugin = ->
      gateway_manager = @gateway_manager
      assert gateway_manager?, 'Missing gateway manager.'

      middleware = ->
        return if @finalized()
        promise_all @res.gateways, (x) -> update gateway_manager, x
        .then (gws) =>
          @res.gateways = gws

    plugin.title = 'Default `gwid` router plugin'
    plugin.description = "Injects the gateway described by the `gwid` into the list of gateways."
    module.exports = plugin

    assert = require 'assert'
    promise_all = require '../promise-all'
