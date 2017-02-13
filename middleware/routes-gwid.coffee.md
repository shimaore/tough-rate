Default `gwid` router plugin
============================

    seem = require 'seem'

    update = (gateway_manager,entry) ->

* doc.prefix.gwlist[].gwid (string) ID of the destination doc.gateway
* doc.destination.gwlist[].gwid (string) ID of the destination doc.gateway
* doc.gateway ignore
* doc.gateway.name (string) Name of the gateway
* doc.gateway.carrier (string) Carrier of the gateway (used for call rating) in format `<sip_domain_name>:<carrierid>`

      return entry unless entry.gwid?
      entry.name ?= "gateway #{entry.gwid}"
      # TODO Add lookup for gateway-faulty or suspicious, and skip the resolution in that case.
      gateway_manager.resolve_gateway entry.gwid

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:routes-gwid"
    @init = ->
      assert @cfg.gateway_manager?, 'Missing gateway manager.'
    @include = seem ->

      return unless @session.direction is 'lcr'

      gateway_manager = @cfg.gateway_manager

      if @res.finalized()
        @debug 'Routes GwID: already finalized.'
        return
      unless @res.gateways?
        @debug 'No gateways'
        return
      @res.gateways = yield promise_all @res.gateways, seem (x) ->
        r = yield update gateway_manager, x
        for gw in r
          gw.destination_number ?= x.destination_number if x.destination_number?
        r

    assert = require 'assert'
    promise_all = require '../promise-all'
