ToughRate Least Cost Router
===========================

We first need to determine which routing table we should use, though.
This is based on the calling number.

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:setup"
    {debug} = (require 'tangible') @name
    @web = ->
      @cfg.versions[pkg.name] = pkg.version
    @include = ->

      return unless @session?.direction is 'lcr'

      session = @session
      respond = (v) => @respond v

      @res[k] ?= v for own k,v of {
        cause: null
        destination: @destination
        source: @session.asserted ? @source
        __finalized: false

`gateways` is an array that either contains gateways, or arrays of gateways

        gateways: []
        rule: null
        ruleset: null
        extra: null
        winner: null
        attrs: {}

Manipulate the gateways list.

        finalize: (callback) ->
          if @finalized()
            debug.dev "`finalize` called when the route-set is already finalized"
            return
          debug 'finalizing'
          @__finalized = true
          callback?()
        finalized: ->
          @__finalized

        sendto: (uri,profile = null) ->
          @finalize =>
            @gateways = [{uri,profile}]
            @gateways[0]

        respond: (v) ->
          @finalize =>
            @gateways = []
            session.call_failed = true
            respond v

        attempt: (gateway) ->
          if @finalized()
            debug.dev "`attempt` called when the route-set is already finalized", gateway
            return
          @gateways.push gateway

        clear: ->
          if @finalized()
            debug.dev "`clear` called when the route-set is already finalized"
            return
          @gateways = []

        attr: (name,value) ->
          return unless name?
          if 'string' is typeof key
            @attrs[name] = value
          else
            for own n,v of name
              @attrs[n] = v

      }

      debug "Starting LCR for call #{@res.source} → #{@res.destination}"

      return

    {EventEmitter} = require 'events'

Init
----

    @server_pre = ->

      return if @cfg.gateway_manager?

Create the gateway-manager.

      nimble = Nimble @cfg
      unless nimble.provisioning?
        debug.dev 'Missing provisioning.'
        return
      prov = new CouchDB nimble.provisioning
      unless @cfg.sip_domain_name?
        debug.dev 'Missing cfg.sip_domain_name.'
        return

* cfg.gateway_manager In pkg:tough-rate, the object that manages gateways and carrier records.

      @cfg.gateway_manager = new GatewayManager prov, @cfg.sip_domain_name

      await @cfg.gateway_manager.init()
      if @cfg.default?
        @cfg.gateway_manager.set @cfg.default
      debug.dev "Gateway Manager started"
      null

    assert = require 'assert'
    GatewayManager = require '../gateway_manager'
    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb'
