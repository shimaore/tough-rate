ToughRate Least Cost Router
===========================

We first need to determine which routing table we should use, though.
This is based on the calling number.

    module.exports = class ToughRateRouter

      constructor: (@logger,@statistics) ->
        @logger ?= require 'winston'
        if not @statistics?
          CaringBand = require 'caring-band'
          @statistics = new CaringBand()
        @logger.info "ToughRateRouter #{pkg.name} #{pkg.version}: ready."
        @middlewares = []

      use: (middleware) ->
        assert middleware.info?, "ToughRateRouter #{pkg.name} #{pkg.version}: middleware #{middleware} should have info."
        @middlewares.push middleware

      route: (call) ->

        source = call.data['Channel-Caller-ID-Number']
        destination = call.data['Channel-Destination-Number']

        ctx = {
          logger: @logger
          statistics: @statistics
          router: this
          call
          data: call.data
          source
          destination
          req:
            header: (name) ->
              call.data["variable_sip_h_#{name}"]
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

          redirect: (destination) ->
            ctx.res.destination = destination

Manipulate the gateways list.

          finalize: (callback) ->
            if ctx.finalized()
              ctx.logger.error "ToughRateRouter #{pkg.name} #{pkg.version}: `finalize` called when the route-set is already finalized"
              return
            ctx.res.finalized = true
            callback?()
          finalized: ->
            ctx.res.finalized
          sendto: (uri) ->
            ctx.finalize ->
              ctx.res.gateways = [{uri}]
          respond: (v) ->
            ctx.finalize ->
              ctx.res.response = v
              ctx.res.gateways = []
          attempt: (gateway) ->
            if ctx.finalized()
              ctx.logger.error "ToughRateRouter #{pkg.name} #{pkg.version}: `attempt` called when the route-set is already finalized", gateway
              return
            ctx.res.gateways.push gateway
          clear: ->
            if ctx.finalized()
              ctx.logger.error "ToughRateRouter #{pkg.name} #{pkg.version}: `clear` called when the route-set is already finalized", gateway
              return
            ctx.res.gateways = []

          set: (name,value) ->
            if 'string' is typeof name
              ctx.res.set[name] = value
            else
              for own n,v of name
                ctx.res.set[n] = v
          unset: (name) ->
            if 'string' is typeof name
              ctx.res.set[name] = null
            else
              for own n,v of name
                ctx.res.set[n] = null

          export: (name,value) ->
            if 'string' is typeof name
              ctx.res.export[name] = value
            else
              for own n,v of name
                ctx.res.export[n] = value

          response_handlers: new EventEmitter()
          on: (response,handler) ->
            ctx.response_handlers.on response, ->
              handler.call this

        }

        it = Promise.resolve()
        it = it.bind ctx
        for middleware in @middlewares
          do (middleware) =>
            it = it.then ->
              middleware.call ctx, ctx
            .catch (error) ->
              @logger.error "ToughRateRouter #{pkg.name} #{pkg.version}: middleware #{middleware.info} failure", error.toString()
        it
        .catch (error) =>
          @logger.error "ToughRateRouter #{pkg.name} #{pkg.version}: middleware failure", error.toString()

Instrument for testing.

        .then ->
          @logger.info "ToughRateRouter #{pkg.name} #{pkg.version}: completed."
          ctx

Toolbox
-------

    {EventEmitter} = require 'events'
    pkg = require './package.json'
    Promise = require 'bluebird'
    assert = require 'assert'
