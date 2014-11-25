    module.exports = ->
      gateway_manager = @gateway_manager
      assert gateway_manager, 'Missing gateway_manager'

      middleware = ->

Helper to report a gateway as faulty to the gateway manager.

        mark_gateway_as_faulty = (gateway) =>
          @logger.info "Asking the gateway manager to mark gateway #{JSON.stringify gateway} as faulty."
          gateway_manager.mark_gateway_as_faulty gateway

Helper to report a gateway as suspicious to the gateway manager.

        mark_gateway_as_suspicious = (gateway) =>
          @logger.info "Asking the router to mark gateway #{JSON.stringify gateway} as suspicious."
          gateway_manager.mark_gateway_as_suspicious gateway

Default call post-processing.

        @on 'CALL_REJECTED',            mark_gateway_as_faulty # 403, 603
        @on 'RECOVERY_ON_TIMER_EXPIRE', mark_gateway_as_faulty # 408, 504
        @on 'NETWORK_OUT_OF_ORDER',     mark_gateway_as_suspicious # 502
        @on 'NORMAL_TEMPORARY_FAILURE', mark_gateway_as_suspicious # 503

Toolbox

    assert = require 'assert'
