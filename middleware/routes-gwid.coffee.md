Default `gwid` router plugin
============================

    update = (entry,gateway_manager) ->

* doc.prefix.gwlist[].gwid (string) ID of the destination doc.gateway
* doc.destination.gwlist[].gwid (string) ID of the destination doc.gateway
* doc.gateway ignore
* doc.gateway.name (string) Name of the gateway
* doc.gateway.carrier (string) Carrier of the gateway (used for call rating) in format `<sip_domain_name>:<carrierid>`

      return entry unless entry.gwid?
      entry.name ?= "gateway #{entry.gwid}"
      # TODO Add lookup for gateway-faulty or suspicious, and skip the resolution in that case.
      gateways = await gateway_manager.resolve_gateway entry.gwid

      {destination_number} = entry
      gateways.map (gw) -> Object.assign gw, {destination_number}

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
      @res.gateways = await promise_all @res.gateways, (x) -> await update x, gateway_manager

      debug 'Gateways', @res.gateways
      return

    assert = require 'assert'
    promise_all = require '../promise-all'
