ToughRate Least Cost Router
===========================

We first need to determine which routing table we should use, though.
This is based on the calling number.

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:setup"
    {debug} = (require 'tangible') @name
    @web = ->
      @cfg.versions[pkg.name] = pkg.version
    @include = (ctx) ->

      return unless @session?.direction is 'lcr'

      debug 'Starting LCR'

      ctx.res[k] ?= v for own k,v of {
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
            debug.dev "`finalize` called when the route-set is already finalized"
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
            debug.dev "`attempt` called when the route-set is already finalized", gateway
            return
          ctx.res.gateways.push gateway

        clear: ->
          if ctx.res.finalized()
            debug.dev "`clear` called when the route-set is already finalized"
            return
          ctx.res.gateways = []

        attr: (name,value) ->
          return unless name?
          if 'string' is typeof key
            ctx.res.attrs[name] = value
          else
            for own n,v of name
              ctx.res.attrs[n] = v

      }

      return

    {EventEmitter} = require 'events'

Init
----

    @server_pre = ->

      return if @cfg.gateway_manager?

Create the gateway-manager.

      unless @cfg.prov?
        debug.dev 'Missing cfg.prov.'
        return
      unless @cfg.sip_domain_name?
        debug.dev 'Missing cfg.sip_domain_name.'
        return

* cfg.gateway_manager In pkg:tough-rate, the object that manages gateways and carrier records.

      @cfg.gateway_manager = new GatewayManager @cfg.prov, @cfg.sip_domain_name

      await @cfg.gateway_manager.init()
      if @cfg.default?
        @cfg.gateway_manager.set @cfg.default
      debug.dev "Gateway Manager started"
      null

    assert = require 'assert'
    GatewayManager = require '../gateway_manager'
