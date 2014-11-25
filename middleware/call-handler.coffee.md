Call Handling Middleware
========================

This middleware is called normally at the end of the stack to process the gateway list and handle responses.

    class CallHandlerMiddlewareError extends Error

    module.exports = ->
      profile = @options.profile
      assert profile?, 'middleware Call Handler: `profile` is required.'

Middleware
----------

      middleware = ->
        send_response = (response) =>
          return @call.command 'respond', response

        @logger.info "Call Handler: starting."

        if @res.response?
          return send_response @res.response

The route-set might not be modified anymore.

        @finalize() unless @finalized()

        @set
          continue_on_fail: true
          hangup_after_bridge: false

The `it` promise will return either a gateway, `false` if no gateway was found, or null if no gateway was successful.

        it = Promise.resolve()
        it = it.bind this

        for own name,value of @res.set
          do (name,value) ->
            it = it.then ->
              if value is null
                @logger.info "Unset #{name}"
                @call.command 'unset', name
              else
                @logger.info "Set #{name} to value #{value}"
                @call.command 'set', "#{name}=#{value}"

        for own name,value of @res.export
          do (name,value) ->
            it = it.then ->
              if value is null
                @logger.info "Export #{name}"
                @call.command 'export', name
              else
                @logger.info "Export #{name} with value #{value}"
                @call.command 'export', "#{name}=#{value}"

If there are gateways, attempt to call through them in the order listed.

        it = it.then ->
          null

        for gateway in @res.gateways
          do (gateway) ->

Should return the winning gateway iff the call was successful and no further attempts should be made.

            it = it.then (winner) ->

If a winner was already found simply return it.

              return winner if winner?

Call attempt.

              @logger.info "Handling next gateway", gateway

              destination = gateway.destination_number ? @res.destination
              attempt.call this, destination, gateway
              .then (res) =>
                @logger.warn "FreeSwitch response: ", res

On CANCEL we get `variable_originate_disposition=ORIGINATOR_CANCEL` instead of a proper `last_bridge_hangup_cause`.

                @res.cause = cause = res.body?.variable_last_bridge_hangup_cause ? res.body?.variable_originate_disposition

                unless cause?
                  @logger.warn "Unable to parse reply '#{res}'", res
                  throw new CallHandlerMiddlewareError "Unable to parse reply"

                thus = Promise.resolve()
                .then =>
                  @response_handlers.emit cause, gateway
                  @response_handlers.emit 'call-completed', gateway
                  cause
                .catch (error) =>
                  @logger.error "Response handler(s) for #{cause} failed.", error.toString()
                  cause

              .then (cause) =>

                if cause is 'NORMAL_CALL_CLEARING'

                  @logger.info "CallHandler: Successfull Call."
                  return gateway # Winner

                else

                  @logger.info "CallHandler: call failed: #{cause} when routing #{destination} through #{JSON.stringify gateway}."
                  return null # No winner yet

However we do not propagate errors, since it would mean interrupting the call sequence. Since we didn't find any winner, we simply return `null`.

              .catch (error) =>
                @logger.error 'Internal or FreeSwitch error (ignored, skipping to next gateway): ', error.toString()
                null

            return

        it.catch (error) ->
          @logger.error "Caught internal error", error.toString()
          send_response '500'
          null

        it.then (winner) ->
          if not winner?
            @logger.warn "No Route."
            send_response '604'
          else
            @logger.info "Call Handler: the winning gateway was: #{JSON.stringify winner}"
            @winner = winner
          null

        return it

Attempt Call
------------

Convert fields found in the record into fields for FreeSwitch `bridge` command.
Returns an `esl` promise that completes when the call gets connected, or 

      attempt = (destination,gateway) ->

        @logger.info "CallHandler: attempt", {destination,gateway}

        leg_options = {}

        for g,l of field_mapping when gateway[g]?
          leg_options[l] = gateway[g]

        if gateway.headers?
          for h of gateway.headers
            leg_options["sip_h_#{h}"] = gateway.headers[h]

FIXME: build a more resistant list.

        leg_options_text = ("#{k}=#{v}" for k,v of leg_options).join ','

Sometimes we'll be provided with a pre-built URI (emergency calls, loopback calls). In other cases we build the URI from the destination number and the gateway's address.

        uri = gateway.uri ? "sip:#{destination}@#{gateway.address}"

        @logger.info "CallHandler: attempt -- bridge [#{leg_options_text}]sofia/#{profile}/#{uri}"
        @call.command 'bridge', "[#{leg_options_text}]sofia/#{profile}/#{uri}"


Plugin
------

      return middleware

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

Toolbox
-------

    Promise = require 'bluebird'
    assert = require 'assert'
