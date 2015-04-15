Default `gwid` router plugin
============================

    update = (gateway_manager,entry) ->
      return entry unless entry.gwid?
      entry.name ?= entry.gwid
      # TODO Add lookup for gateway-faulty or suspicious, and skip the resolution in that case.
      gateway_manager.resolve_gateway entry.gwid

    plugin = ->
      gateway_manager = @cfg.gateway_manager
      assert gateway_manager?, 'Missing gateway manager.'

      middleware = ->
        if @finalized()
          @logger.info 'Routes GwID: already finalized.'
          return
        promise_all @res.gateways, (x) ->
          Promise.resolve()
          .then ->
            update gateway_manager, x
          .then (r) ->
            for gw in r
              gw.destination_number ?= x.destination_number if x.destination_number?
            r
        .then (gws) =>
          @res.gateways = gws

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

    plugin.title = 'Default `gwid` router plugin'
    plugin.description = "Injects the gateway described by the `gwid` into the list of gateways."
    module.exports = plugin

    assert = require 'assert'
    Promise = require 'bluebird'
    promise_all = require '../promise-all'
    pkg = require '../package.json'
