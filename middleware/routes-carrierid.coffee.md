Default `carrierid` router plugin
=================================

    seem = require 'seem'

Replace all carrierid entries with matching definitions.

    update = seem (gateway_manager,host,entry) ->

* doc.prefix.gwlist[].carrierid (string) name of the destination doc.carrier
* doc.destination.gwlist[].carrierid (string) name of the destination doc.carrier
* doc.carrier ignore

      return entry unless entry.carrierid?
      gateways = yield gateway_manager.resolve_carrier entry.carrierid
      count = gateways[0]?.try

      gateways.forEach (gateway) =>
        gateway.priority = 1

First we must sort the carrier entries using the local hostname preference.

        if gateway.local_gateway_first and host? and gateway.host is host
          gateway.priority += 0.5

* doc.carrier.name Name of the carrier

        gateway.name ?= entry.name ? "carrier #{entry.carrierid}"
        # TODO Lookup faulty/suspicious status and skip in that case (i.e. set priority to 0)

      gateways.sort (a,b) ->
        if a.priority isnt b.priority
          a.priority - b.priority

If gateways have the same priority, randomize / load-balance.

        else
          Math.random()-0.5

And select only `try` entries where specified.

      if count? and count > 0
        gateways = gateways[0...count]

      gateways

Middleware definition
---------------------

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:routes-carrierid"
    @include = seem ->

      return unless @session.direction is 'lcr'

      gateway_manager = @cfg.gateway_manager
      host = @cfg.host

      unless gateway_manager?
        @debug.dev 'Missing gateway manager'
        return

      if @res.finalized()
        @debug "Routes CarrierID: already finalized."
        return
      unless @res.gateways?
        @debug 'No gateways'
        return
      @res.gateways = yield promise_all @res.gateways, seem (x) ->
        r = yield update gateway_manager, host, x
        for gw in r
          gw.destination_number ?= x.destination_number if x.destination_number?
        r

      @debug 'Gateways', @res.gateways
      return

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
