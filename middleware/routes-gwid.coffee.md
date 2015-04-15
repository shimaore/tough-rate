Default `gwid` router plugin
============================

    update = (gateway_manager,entry) ->
      return entry unless entry.gwid?
      entry.name ?= entry.gwid
      # TODO Add lookup for gateway-faulty or suspicious, and skip the resolution in that case.
      gateway_manager.resolve_gateway entry.gwid

    @name = 'routes-gwid'
    @include = ->
      gateway_manager = @cfg.gateway_manager
      assert gateway_manager?, 'Missing gateway manager.'

      if @finalized()
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
