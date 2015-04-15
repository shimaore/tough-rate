    module.exports = ->
      gateway_manager = @cfg.gateway_manager
      assert gateway_manager, 'Missing gateway_manager'

      middleware = ->

        gateway_to_id = (gateway) ->

Helper to report a gateway as faulty to the gateway manager.

        mark_gateway_as_faulty = (gateway) =>
          debug "Asking the gateway manager to mark gateway #{JSON.stringify gateway} as faulty."
          if gateway.name?
            gateway_manager.mark_gateway_as_faulty gateway.name

Helper to report a gateway as suspicious to the gateway manager.

        mark_gateway_as_suspicious = (gateway) =>
          debug "Asking the router to mark gateway #{JSON.stringify gateway} as suspicious."
          if gateway.name?
            gateway_manager.mark_gateway_as_suspicious gateway.name

Default call post-processing.

        @on 'CALL_REJECTED',            mark_gateway_as_faulty # 403, 603
        @on 'RECOVERY_ON_TIMER_EXPIRE', mark_gateway_as_faulty # 408, 504
        @on 'NETWORK_OUT_OF_ORDER',     mark_gateway_as_suspicious # 502
        @on 'NORMAL_TEMPORARY_FAILURE', mark_gateway_as_suspicious # 503

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

Toolbox

    assert = require 'assert'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:response-handlers"
