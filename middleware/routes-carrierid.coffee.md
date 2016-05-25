Default `carrierid` router plugin
=================================

Replace all carrierid entries with matching definitions.

    update = (gateway_manager,host,entry) ->

* doc.rule.gwlist[].carrierid (string) name of the destination doc.carrier
* doc.carrier ignore

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

    @name = 'routes-carrierid'
    @init = ->
      assert @cfg.gateway_manager?, 'Missing `gateway_manager`.'
    @include = ->
      gateway_manager = @cfg.gateway_manager
      host = @cfg.host

      if @res.finalized()
        debug "Routes CarrierID: already finalized."
        return
      promise_all @res.gateways, (x) ->
        Promise.resolve()
        .then ->
          update gateway_manager, host, x
        .then (r) ->
          for gw in r
            gw.destination_number ?= x.destination_number if x.destination_number?
          r
      .then (gws) =>
        @res.gateways = gws

Toolbox
-------

    assert = require 'assert'
    Promise = require 'bluebird'
    promise_all = require '../promise-all'
    field_merger = require '../field_merger'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:routes-carrierid"
