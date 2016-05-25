ToughRate Least Cost Router
===========================

We first need to determine which routing table we should use, though.
This is based on the calling number.

    @name = 'setup'
    @web = ->
      @cfg.versions[pkg.name] = pkg.version
    @include = (ctx) ->

      return unless @session.direction is 'lcr'

      ctx[k] ?= v for own k,v of {
        statistics: @cfg.statistics
        res:
          cause: null
          destination: @destination # aka final_destination
          __finalized: false

`gateways` is an array that either contains gateways, or arrays of gateways

          gateways: []
          winner: null
          attrs: {}

          redirect: (destination) ->
            ctx.res.destination = destination

Manipulate the gateways list.

          finalize: (callback) ->
            if ctx.res.finalized()
              debug "`finalize` called when the route-set is already finalized"
              return
            debug 'finalizing'
            ctx.res.__finalized = true
            callback?()
          finalized: ->
            ctx.res.__finalized

          sendto: (uri,profile = null) ->
            ctx.res.finalize ->
              ctx.res.gateways = [{uri,profile}]
              ctx.res.gateways[0]

          respond: (v) ->
            ctx.res.finalize ->
              ctx.res.gateways = []
              ctx.session.call_failed = true
              ctx.respond v

          attempt: (gateway) ->
            if ctx.res.finalized()
              debug "`attempt` called when the route-set is already finalized", gateway
              return
            ctx.res.gateways.push gateway

          clear: ->
            if ctx.res.finalized()
              debug "`clear` called when the route-set is already finalized"
              return
            ctx.res.gateways = []

          attr: (name,value) ->
            return unless name?
            if 'string' is typeof key
              ctx.res.attrs[name] = value
            else
              for own n,v of name
                ctx.res.attrs[n] = v

        response_handlers: new EventEmitter()
        on: (response,handler) ->
          ctx.response_handlers.on response, ->
            handler.apply this, arguments

      }
      return

    {EventEmitter} = require 'events'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:setup"

Init
----

    @init = ->

      return if @cfg.gateway_manager?

Create the gateway-manager.

      assert @cfg.prov?, 'Missing `prov`.'
      assert @cfg.sip_domain_name?, 'Missing `sip_domain_name`.'

* cfg.gateway_manager In pkg:tough-rate, the object that manages gateways and carrier records.

      @cfg.gateway_manager = new GatewayManager @cfg.prov, @cfg.sip_domain_name

      @cfg.gateway_manager.init()
      .catch (error) =>
        debug "CallServer startup error: Gateway Manager failed: #{error}"

      .then =>
        if @cfg.default?
          @cfg.gateway_manager.set @cfg.default
        null

    assert = require 'assert'
    GatewayManager = require '../gateway_manager'
    pkg = require '../package.json'
