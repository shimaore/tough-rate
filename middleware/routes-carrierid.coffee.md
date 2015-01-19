Default `carrierid` router plugin
=================================

Replace all carrierid entries with matching definitions.

    update = (gateway_manager,host,entry) ->
      return entry unless entry.carrierid?
      gateway_manager.resolve_carrier entry.carrierid
      .then (gateways) =>
        gateways.forEach (gateway) =>
          gateway.priority = 1

First we must sort the carrier entries using the local hostname preference.

          if gateway.local_gateway_first and host? and gateway.host is host
            gateway.priority += 0.5

          gateway.name ?= "carrier #{entry.carrierid}"
          # TODO Lookup faulty/suspicious status and skip in that case (i.e. set priority to 0)

        gateways.sort (a,b) -> a.priority - b.priority

And select only `try` entries where specified.

        count = gateways[0]?.try
        if count? and count > 0
          gateways = gateways[0...count]

        gateways

Middleware definition
---------------------

    plugin = ->
      gateway_manager = @gateway_manager
      host = @options.host
      assert gateway_manager?, 'Missing gateway manager.'

      middleware = ->
        if @finalized()
          @logger.info "Routes CarrierID: already finalized."
          return
        promise_all @res.gateways, (x) -> update gateway_manager, host, x
        .then (gws) =>
          @res.gateways = gws

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

    plugin.title = 'Default `carrierid` plugin'
    plugin.description = "Injects the gateways described by the `carrierid` into the router's list of gateways."
    module.exports = plugin

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
    field_merger = require '../field_merger'
    pkg = require '../package.json'
