Default `gwid` router plugin
============================

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
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

      gateway_manager = @cfg.gateway_manager

      unless gateway_manager?
        debug.dev 'Missing gateway manager'
        return

      if @res.finalized()
        debug 'Routes GwID: already finalized.'
        return
      unless @res.gateways?
        debug 'No gateways'
        return
      @res.gateways = await promise_all @res.gateways, (x) ->
        r = await update gateway_manager, x
        for gw in r
          gw.destination_number ?= x.destination_number if x.destination_number?
        r

      debug 'Gateways', @res.gateways
      return

    assert = require 'assert'
    promise_all = require '../promise-all'
