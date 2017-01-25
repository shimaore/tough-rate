Call Handling Middleware
========================

This middleware is called normally at the end of the stack to process the gateway list and handle responses.

    seem = require 'seem'

    class CallHandlerMiddlewareError extends Error

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:call-handler"

    @init = ->
      debug 'Missing `profile`.' unless @cfg.profile?

    @include = seem ->

      return unless @session.direction is 'lcr'

Attempt Call
------------

Convert fields found in the record into fields for FreeSwitch `bridge` command.
Returns an `esl` promise that completes when the call gets connected.

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
        profile = gateway.profile
        profile ?= @session.sip_profile
        profile ?= @cfg.profile

        debug "CallHandler: attempt -- bridge [#{leg_options_text}]sofia/#{profile}/#{uri}"
        @action 'bridge', "[#{leg_options_text}]sofia/#{profile}/#{uri}"

Middleware
----------

      @statistics.add ['incoming-calls',@rule?.prefix]

The route-set might not be modified anymore.

      @res.finalize() unless @res.finalized()

Do not process further if we already responded.

      if @session.call_failed?
        debug "Already responded", @session.first_response_was
        return

The `it` promise will return either a gateway, `false` if no gateway was found, or null if no gateway was successful.

      yield @set
        continue_on_fail: true
        hangup_after_bridge: false

      @session.sip_wait_for_aleg_ack ?= true
      yield @export sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack
      yield @set sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack
      if @session.handled_transfer_context?
        yield @set force_transfer_context: @session.handled_transfer_context

If there are gateways, attempt to call through them in the order listed.

      winner = null

      for gateway in @res.gateways when not winner?

Call attempt.

        try

          debug "CallHandler: handling (next) gateway", gateway
          @statistics.add 'call-attempts'
          @statistics.add ['call-attempts',@rule?.prefix]
          @statistics.add ['call-attempts-gw',gateway.gwid]
          @statistics.add ['call-attempts-carrier',gateway.carrierid]
          @report state: 'call-attempt'

          destination = gateway.destination_number ? @res.destination
          @session.gateway = gateway
          @session.destination = destination
          res = yield attempt
            .call this, destination, gateway
            .catch (error) ->
              debug "attempt error: #{error.stack ? error}"
              body: {}
          data = res.body
          @session.bridge_data ?= []
          @session.bridge_data.push data

          debug "CallHandler: FreeSwitch response: ", res
          @statistics.add 'call-status'

On CANCEL we get `variable_originate_disposition=ORIGINATOR_CANCEL` instead of a proper `last_bridge_hangup_cause`.
On successful connection we also get `variable_originate_disposition=SUCCESS, variable_DIALSTATUS=SUCCESS`.

          @res.cause = cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition

          unless cause?
            debug "CallHandler: Unable to parse reply '#{res}'", res
            continue

          try
            @response_handlers.emit cause, gateway
            @response_handlers.emit 'call-completed', gateway
          catch error
            debug "CallHandler: Response handler(s) for #{cause} failed: #{error.stack ? error}"

          @statistics.add ['cause',cause]
          @statistics.add ['cause-gw',cause,gateway.gwid]
          @statistics.add ['cause-gw',cause,gateway.gwid,@rule?.prefix]
          @statistics.add ['cause-carrier',cause,gateway.carrierid]
          @statistics.add ['cause-carrier',cause,gateway.carrierid,@rule?.prefix]

          @session.was_connected = cause in ['NORMAL_CALL_CLEARING', 'NORMAL_CLEARING', 'SUCCESS']
          @session.was_transferred = data.variable_transfer_history?

          switch
            when @session.was_connected

              debug "CallHandler: connected call: #{cause} when routing #{destination} through #{JSON.stringify gateway}."
              @statistics.add 'connected-calls'
              @statistics.add ['connected-calls-gw',gateway.gwid]
              @statistics.add ['connected-calls-carrier',gateway.carrierid]
              winner = gateway # Winner
              @session.winner = gateway

            when @session.was_transferred

              debug "CallHandler: transferred call: #{cause} when routing #{destination} through #{JSON.stringify gateway}."
              @statistics.add 'transferred-calls'
              @statistics.add ['transferred-calls-gw',gateway.gwid]
              @statistics.add ['transferred-calls-carrier',gateway.carrierid]
              winner = gateway # Winner
              @session.winner = gateway

            else

              debug "CallHandler: failed call: #{cause} when routing #{destination} through #{JSON.stringify gateway}."
              @statistics.add 'failed-attempts'
              @statistics.add ['failed-attempts-gw',gateway.gwid]
              @statistics.add ['failed-attempts-gw',gateway.gwid,cause]
              @statistics.add ['failed-attempts-carrier',gateway.carrierid]
              @statistics.add ['failed-attempts-carrier',gateway.carrierid,cause]
              # No winner yet

However we do not propagate errors, since it would mean interrupting the call sequence. Since we didn't find any winner, we simply return `null`.

        catch error
          debug 'Internal or FreeSwitch error (ignored, skipping to next gateway): ', error.toString()
          @statistics.add 'gateway-skip'

      if not winner?
        debug "CallHandler: No Route."
        @statistics.add 'no-route'
        yield @respond '604'
      else
        debug "CallHandler: the winning gateway was: #{JSON.stringify winner}"
        @statistics.add 'route'
        @res.winner = winner
        @res.attr winner.attrs

Release leaking fields

      @res.ruleset = null
      @res.ruleset_database = null

      return


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

    assert = require 'assert'
    debug = (require 'debug') @name
    cuddly = (require 'cuddly') @name
