Call Handler
============

This is the LCR call handler. It is responsible for managing the entire call. Use it as `FS.server CallHandler router, options` where the router is an instance of CallRouter.
Options are:
- `profile`: name of the outbound Sofia-SIP profile to use [required]
- `statistics`: winston instance

    class CallHandlerError extends Error

    module.exports = CallHandler = (router,options) ->
      assert options.profile?, 'Missing `profile` option.'
      assert options.statistics?, 'Missing `statistics` option.'

      handler = ->

        respond = (v) =>
          @command 'respond', v

We modify the CallRouter's options so that it has access to our respond. (FIXME)

        router.options.respond = respond

        route_doc = null

        destination = @data['Channel-Destination-Number']
        unless destination? and destination.match /^[\d#*]+$/
          respond '484'
          options.statistics.warn 'Missing or invalid Channel-Destination-Number', @data
          return

        source = @data['Channel-Caller-ID-Number']
        unless source? and source.match /^\d+$/
          respond '484'
          options.statistics.warn 'Missing or invalid Channel-Caller-ID-Number', @data
          return

        emergency_ref = @data['variable_sip_h_X-CCNQ3-Routing']

Then, see whether the destination number is an emergency number, and process it.

        # This is done by the router.

Go through the gateways.

        router.route source, destination, emergency_ref
        .catch (exception)->
          options.statistics.error "Call Router exception: #{exception}"
          false
        .then (gateways) =>

          options.statistics.info "CallHandler: gateways = #{JSON.stringify gateways}"

The `it` promise will return either a gateway, `false` if no gateway was found, or null if no gateway was successful.

          if gateways is false
            return Promise.resolve false

          it = Promise.resolve()

If there are gateways, attempt to call through them in the order listed.

          for gateway in gateways
            do (gateway) =>

Should return the winning gateway iff the call was successful and no further attempts should be made.

              it = it.then (winner) =>

                options.statistics.info "Handling next gateway.", gateway

If a winner was already found simply return it.

                return winner if winner?

Call attempt.

                final_destination = gateway.final_destination ? destination
                attempt.call this, final_destination, gateway, options

If we've got a winner, propagate it down.

                .then (res) ->

                  options.statistics.warn {res}
                  cause = res.body.variable_last_bridge_hangup_cause

                  if cause is 'NORMAL_CALL_CLEARING'
                    options.statistics.info "CallHandler: Successfull Call."
                    return gateway


Those error are reported iff the call was not able to connect for some reason.

                  unless cause?
                    options.statistics.warn "Unable to parse reply '#{res}'"
                    throw new CallHandlerError "Unable to parse reply '#{res}'"

                  options.statistics.info "CallHandler: call failed: #{cause} when routing #{final_destination} through #{JSON.stringify gateway}."

                  thus = Promise.resolve()
                  .then ->
                    response_handlers[cause]?.call this, gateway, router, options, destination, final_destination
                    null
                  .catch (error) ->
                    options.statistics.error "Response handler for #{cause} failed.", error
                    null

                  return thus

              .catch (error) ->

                options.statistics.error "Internal error.", error

However we do not propagate `error`, since it would mean interrupting the call sequence. Since we didn't find any winner, we simply return `null`.

                null

              return

Last resort, indicate no route found.

          it.catch (error) ->
            options.statistics.error "Caught internal error.", error
            respond '500'
            null

          it.then (winner) ->

If no gateways were found (`winner === false`) this is because the CallRouter returned an error and already notified the client; we do not need to notify again in that case.
We only need to notify if we tried gateways but none responded properly, in which case `winner === null`.

            if not winner?
              options.statistics.warn "No Route."
              respond '604' # No Route

            # TODO log the winning gateway
            options.statistics.info "CallHandler: the winning gateway was: #{JSON.stringify winner}"
            # Note: winner might be `true` if no gateways were available.

            null

          return it

      return handler


Attempt Call
============

Convert fields found in the record into fields for FreeSwitch `bridge` command.
Returns an `esl` promise that completes when the call gets connected, or 

    attempt = (destination,gateway,options) ->

      options.statistics.info "CallHandler: attempt", {destination, gateway}

      leg_options = {}

      for g,l of field_mapping when gateway[g]?
        leg_options[l] = gateway[g]

FIXME: build a more resistant list.

      leg_options_text = ("#{k}=#{v}" for k,v of leg_options).join ','

Sometimes we'll be provided with a pre-built URI (emergency calls, loopback calls). In other cases we build the URI from the destination number and the gateway's address.

      uri = gateway.uri ? "sip:#{destination}@#{gateway.address}"

      options.statistics.info "CallHandler: attempt -- set continue_on_fail=true"
      @command 'set', 'continue_on_fail=true'
      .then ->
        options.statistics.info "CallHandler: attempt -- set hangup_after_bridge=false"
        @command 'set', 'hangup_after_bridge=false'
      .then ->
        options.statistics.info "CallHandler: attempt -- bridge [#{leg_options_text}]sofia/#{options.profile}/#{uri}"
        @command 'bridge', "[#{leg_options_text}]sofia/#{options.profile}/#{uri}"

Field Mapping
=============

Translation from database-side names to FreeSwitch field names.

    field_mapping =

counts from the time the INVITE is placed until a progress indication (e.g. 180, 183) is received. Controls Post-Dial-Delay on this leg.

      progress_timeout: 'leg_progress_timeout'

counts from the progress indication onwards.

      answer_timeout: 'leg_timeout'

call duration

      dialog_timeout: 'sofia_session_timeout'

Response Handlers
=================

Handlers for specific error cases. Keys are FreeSwitch error names.

    response_handlers =
        RECOVERY_ON_TIMER_EXPIRE: mark_gateway_as_faulty # 408, 504
        NETWORK_OUT_OF_ORDER: mark_gateway_as_suspicious # 502
        NORMAL_TEMPORARY_FAILURE: mark_gateway_as_suspicious # 503
        CALL_REJECTED: mark_gateway_as_faulty # 403, 603

Helper to report a gateway as faulty to the gateway manager.

    mark_gateway_as_faulty = (gateway,router,options) ->
      # Do something to report the gateway as faulty (e.g. set `temporarily_disabled`).
      options.statistics.info "Asking the router to mark gateway #{JSON.stringify gateway} as faulty."
      router.gateway_manager.mark_gateway_as_faulty gateway
      # Note that `@` refers to the ongoing call.

Helper to report a gateway as suspicious to the gateway manager.

    mark_gateway_as_suspicious = (gateway,router,options) ->
      # Do something to report the gateway as faulty (e.g. set `temporarily_disabled`).
      options.statistics.info "Asking the router to mark gateway #{JSON.stringify gateway} as suspicious."
      router.gateway_manager.mark_gateway_as_suspicious gateway
      # Note that `@` refers to the ongoing call.

Toolbox
=======

    Promise = require 'bluebird'
    assert = require 'assert'
