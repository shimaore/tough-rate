Default `gwid` router plugin
============================

    update = (gateway_manager,entry) ->

* doc.rule.gwlist[].gwid (string) ID of the destination doc.gateway
* doc.gateway ignore

      return entry unless entry.gwid?
      entry.name ?= entry.gwid
      # TODO Add lookup for gateway-faulty or suspicious, and skip the resolution in that case.
      gateway_manager.resolve_gateway entry.gwid

    @name = 'routes-gwid'
    @init = ->
      assert @cfg.gateway_manager?, 'Missing gateway manager.'
    @include = ->

      return unless @session.direction is 'lcr'

      gateway_manager = @cfg.gateway_manager

      if @res.finalized()
        debug 'Routes GwID: already finalized.'
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

    assert = require 'assert'
    Promise = require 'bluebird'
    promise_all = require '../promise-all'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:routes-gwid"
