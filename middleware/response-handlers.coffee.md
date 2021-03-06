    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:response-handlers"
    {debug} = (require 'tangible') @name

    @include = ->

      return unless @session?.direction is 'lcr'

      gateway_manager = @cfg.gateway_manager

      unless gateway_manager?
        debug.dev 'Missing gateway manager'
        return

      gateway_to_id = (gateway) ->

Helper to report a gateway as faulty to the gateway manager.

      mark_gateway_as_faulty = (gateway) =>
        debug "Asking the gateway manager to mark gateway as faulty.", gateway.name
        if gateway.name?
          gateway_manager.mark_gateway_as_faulty gateway.name

Helper to report a gateway as suspicious to the gateway manager.

      mark_gateway_as_suspicious = (gateway) =>
        debug "Asking the router to mark gateway as suspicious.", gateway.name
        if gateway.name?
          gateway_manager.mark_gateway_as_suspicious gateway.name

Default call post-processing.

      @once 'gateway:CALL_REJECTED', ->
        mark_gateway_as_faulty # 403, 603
      @once 'gateway:RECOVERY_ON_TIMER_EXPIRE', ->
        mark_gateway_as_faulty # 408, 504
      @once 'gateway:NETWORK_OUT_OF_ORDER', ->
        mark_gateway_as_suspicious # 502
      @once 'gateway:NORMAL_TEMPORARY_FAILURE', ->
        mark_gateway_as_suspicious # 503

Make sure to not return a blocking Promise.

      null
