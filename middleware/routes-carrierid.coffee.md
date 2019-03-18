Default `carrierid` router plugin
=================================

Replace all carrierid entries with matching definitions.

    update = (entry,gateway_manager,host) ->

* doc.prefix.gwlist[].carrierid (string) name of the destination doc.carrier
* doc.destination.gwlist[].carrierid (string) name of the destination doc.carrier
* doc.carrier ignore

      return entry unless entry.carrierid?
      gateways = await gateway_manager.resolve_carrier entry.carrierid
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

      {destination_number} = entry
      gateways.map (gw) -> Object.assign gw, {destination_number}

Middleware definition
---------------------

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:routes-carrierid"
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

      gateway_manager = @cfg.gateway_manager
      host = @cfg.host

      unless gateway_manager?
        debug.dev 'Missing gateway manager'
        return

      if @res.finalized()
        debug "Routes CarrierID: already finalized."
        return
      unless @res.gateways?
        debug 'No gateways'
        return

      @res.gateways = await promise_all @res.gateways, (x) -> await update x, gateway_manager, host

      debug 'Gateways', @res.gateways
      return

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
