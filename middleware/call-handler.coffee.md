Call Handling Middleware
========================

This middleware is called normally at the end of the stack to process the gateway list and handle responses.

    class CallHandlerMiddlewareError extends Error

    module.exports = ->
      profile = @cfg.options.profile
      assert profile?, 'middleware Call Handler: `profile` is required.'

Middleware
----------

      middleware = ->
        @statistics.add 'incoming-calls'
        @statistics.add ['incoming-calls',@rule?.prefix]
        @statistics.emit 'call',
          state: 'incoming-call'
          call: @call.uuid
          source: @source
          destination: @destination

        send_response = (response) =>
          return @call.command 'respond', response

        debug "CallHandler: starting."

        if @res.response?
          @statistics.add ['immediate-response',@res.response]
          @statistics.emit 'call',
            state: 'immediate-response'
            call: @call.uuid
            source: @source
            destination: @destination
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
                debug "CallHandler: unset #{name}"
                @call.command 'unset', name
              else
                debug "CallHandler: set #{name} to value #{value}"
                @call.command 'set', "#{name}=#{value}"

        for own name,value of @res.export
          do (name,value) ->
            it = it.then ->
              if value is null
                debug "CallHandler: export #{name}"
                @call.command 'export', name
              else
                debug "CallHandler: export #{name} with value #{value}"
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

              debug "CallHandler: handling (next) gateway", gateway
              @statistics.add 'call-attempts'
              @statistics.add ['call-attempts',@rule?.prefix]
              @statistics.emit 'call',
                state: 'call-attempt'
                call: @call.uuid
                source: @source
                destination: @destination

              destination = gateway.destination_number ? @res.destination
              attempt.call this, destination, gateway
              .then (res) =>
                data = res.body

                debug "CallHandler: FreeSwitch response: ", res
                @statistics.add 'call-status'

On CANCEL we get `variable_originate_disposition=ORIGINATOR_CANCEL` instead of a proper `last_bridge_hangup_cause`.
On successful connection we also get `variable_originate_disposition=SUCCESS, variable_DIALSTATUS=SUCCESS`.

                @res.cause = cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition

                unless cause?
                  debug "CallHandler: Unable to parse reply '#{res}'", res
                  throw new CallHandlerMiddlewareError "Unable to parse reply"

                thus = Promise.resolve()
                .then =>
                  @response_handlers.emit cause, gateway
                  @response_handlers.emit 'call-completed', gateway
                  cause
                .catch (error) =>
                  debug "CallHandler: Response handler(s) for #{cause} failed.", error.toString()
                  cause

              .then (cause) =>

                @statistics.add ['cause',cause]
                @statistics.add ['cause-gw',cause,gateway.gwid]
                @statistics.add ['cause-gw',cause,gateway.gwid,@rule?.prefix]
                @statistics.add ['cause-carrier',cause,gateway.carrierid]
                @statistics.add ['cause-carrier',cause,gateway.carrierid,@rule?.prefix]

                if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS']

                  debug "CallHandler: successful call: #{cause} when routing #{destination} through #{JSON.stringify gateway}."
                  @statistics.add 'connected-calls'
                  @statistics.add ['connected-calls-gw',gateway.gwid]
                  @statistics.add ['connected-calls-carrier',gateway.carrierid]
                  return gateway # Winner

                else

                  debug "CallHandler: call failed: #{cause} when routing #{destination} through #{JSON.stringify gateway}."
                  @statistics.add 'failed-attempts'
                  @statistics.add ['failed-attempts-gw',gateway.gwid]
                  @statistics.add ['failed-attempts-gw',gateway.gwid,cause]
                  @statistics.add ['failed-attempts-carrier',gateway.carrierid]
                  @statistics.add ['failed-attempts-carrier',gateway.carrierid,cause]
                  return null # No winner yet

However we do not propagate errors, since it would mean interrupting the call sequence. Since we didn't find any winner, we simply return `null`.

              .catch (error) =>
                debug 'Internal or FreeSwitch error (ignored, skipping to next gateway): ', error.toString()
                @statistics.add 'gateway-skip'
                null

            return

        it.catch (error) ->
          debug "CallHandler: Caught internal error", error.toString()
          @statistics.add 'internal-error'
          send_response '500'
          null

        .then (winner) ->
          if not winner?
            debug "CallHandler: No Route."
            @statistics.add 'no-route'
            send_response '604'
          else
            debug "CallHandler: the winning gateway was: #{JSON.stringify winner}"
            @statistics.add 'route'
            @winner = winner
            @attr @winner.attrs
          null

        return it

Attempt Call
------------

Convert fields found in the record into fields for FreeSwitch `bridge` command.
Returns an `esl` promise that completes when the call gets connected, or 

      attempt = (destination,gateway) ->

        debug "CallHandler: attempt", {destination,gateway}

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

        debug "CallHandler: attempt -- bridge [#{leg_options_text}]sofia/#{profile}/#{uri}"
        @call.command 'bridge', "[#{leg_options_text}]sofia/#{profile}/#{uri}"


Plugin
------

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

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
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:call-handler"
