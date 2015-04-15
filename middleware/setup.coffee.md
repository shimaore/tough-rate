ToughRate Least Cost Router
===========================

We first need to determine which routing table we should use, though.
This is based on the calling number.

    @include = (ctx) ->

        ctx[k] ?= v for own k,v of {
          logger: @cfg.logger
          statistics: @cfg.statistics
          res:
            cause: null
            destination: destination # aka final_destination
            finalized: false

`gateways` is an array that either contains gateways, or arrays of gateways

            gateways: []
            response: null
            winner: null
            set: {}
            export: {}
            attrs: {}

          redirect: (destination) ->
            ctx.res.destination = destination

Manipulate the gateways list.

          finalize: (callback) ->
            if ctx.finalized()
              debug "ToughRateRouter #{pkg.name} #{pkg.version}: `finalize` called when the route-set is already finalized"
              return
            ctx.res.finalized = true
            callback?()
          finalized: ->
            ctx.res.finalized
          sendto: (uri) ->
            ctx.finalize ->
              ctx.res.gateways = [{uri}]
              ctx.res.gateways[0]
          respond: (v) ->
            ctx.finalize ->
              ctx.res.response = v
              ctx.res.gateways = []
          attempt: (gateway) ->
            if ctx.finalized()
              debug "ToughRateRouter #{pkg.name} #{pkg.version}: `attempt` called when the route-set is already finalized", gateway
              return
            ctx.res.gateways.push gateway
          clear: ->
            if ctx.finalized()
              debug "ToughRateRouter #{pkg.name} #{pkg.version}: `clear` called when the route-set is already finalized", gateway
              return
            ctx.res.gateways = []

          set: (name,value) ->
            return unless name?
            if 'string' is typeof name
              ctx.res.set[name] = value
            else
              for own n,v of name
                ctx.res.set[n] = v
          unset: (name) ->
            return unless name?
            if 'string' is typeof name
              ctx.res.set[name] = null
            else
              for own n,v of name
                ctx.res.set[n] = null

          attr: (name,value) ->
            return unless name?
            if 'string' is typeof key
              ctx.res.attrs[name] = value
            else
              for own n,v of name
                ctx.res.attrs[n] = v

          export: (name,value) ->
            return unless name?
            if 'string' is typeof name
              ctx.res.export[name] = value
            else
              for own n,v of name
                ctx.res.export[n] = value

          response_handlers: new EventEmitter()
          on: (response,handler) ->
            ctx.response_handlers.on response, ->
              handler.apply this, arguments

        }

Toolbox
-------

    {EventEmitter} = require 'events'
    pkg = require './package.json'
    debug = (require 'debug') "#{pkg.name}:router"
    assert = require 'assert'
