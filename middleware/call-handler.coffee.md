Call Handling Middleware
========================

This middleware is called normally at the end of the stack to process the gateway list and handle responses.

    class CallHandlerMiddlewareError extends Error

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:call-handler"
    {debug} = (require 'tangible') @name

    @server_pre = ->
      debug 'Missing `profile`.' unless @cfg.profile?

    escape = (v) ->
      "#{v}".replace ',', ','

    make_params = (data) ->
      ("#{k}=#{escape v}" for own k,v of data).join ','

    @include = ->

      return unless @session?.direction is 'lcr'

Attempt Call
------------

Convert fields found in the record into fields for FreeSwitch `bridge` command.
Returns an `esl` promise that completes when the call gets connected.

      attempt = (gateway) =>

        debug "CallHandler: attempt", gateway

        leg_options = @session?.leg_options ? {}

        for g,l of field_mapping when gateway[g]?
          leg_options[l] = gateway[g]

        if gateway.headers?
          for h of gateway.headers
            leg_options["sip_h_#{h}"] = gateway.headers[h]

        leg_options.effective_caller_id_number =
        leg_options.origination_caller_id_number = gateway.source_number

        leg_options_text = make_params leg_options

        call_options = @session.call_options ? {}

        call_options_text = make_params call_options

Sometimes we'll be provided with a pre-built URI (emergency calls, loopback calls). In other cases we build the URI from the destination number and the gateway's address.

        uri = gateway.uri ? "sip:#{gateway.destination_number}@#{gateway.address}"
        profile = gateway.profile
        profile ?= @session.sip_profile
        profile ?= @cfg.profile

        debug "CallHandler: attempt -- bridge [#{leg_options_text}]sofia/#{profile}/#{uri}"
        @action 'bridge', "{#{call_options_text}}[#{leg_options_text}]sofia/#{profile}/#{uri}"

Middleware
----------

The route-set might not be modified anymore.

      @res.finalize() unless @res.finalized()

Do not process further if we already responded.

      if @session.call_failed?
        debug "Already responded", @session.first_response_was
        return

The `it` promise will return either a gateway, `false` if no gateway was found, or null if no gateway was successful.

      await @set
        continue_on_fail: true

      @session.sip_wait_for_aleg_ack ?= true
      await @export sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack
      await @set sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack
      if @session.handled_transfer_context?
        await @set force_transfer_context: @session.handled_transfer_context

If there are gateways, attempt to call through them in the order listed.

      winner = null

      for gateway in @res.gateways when not winner?

Call attempt.

        try

          debug "CallHandler: handling (next) gateway", gateway
          @notify state: 'call-attempt'

          @session.gateway = gateway
          @session.source = gateway.source_number
          @session.destination = gateway.destination_number

          res = await attempt gateway
            .catch (error) =>
              debug "attempt error: #{error.stack ? error}"
              body: {}
          data = res.body
          @session.bridge_data ?= []
          @session.bridge_data.push data

On CANCEL we get `variable_originate_disposition=ORIGINATOR_CANCEL` instead of a proper `last_bridge_hangup_cause`.
On successful connection we also get `variable_originate_disposition=SUCCESS, variable_DIALSTATUS=SUCCESS`.

          @res.cause = cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition

          unless cause?
            debug.dev "CallHandler: Unable to parse reply"
            continue

          @session.was_connected = cause in ['NORMAL_CALL_CLEARING', 'NORMAL_CLEARING', 'SUCCESS']
          @session.was_transferred = data.variable_transfer_history? or
            data.variable_endpoint_disposition is 'BLIND_TRANSFER' or
            data.variable_endpoint_disposition is 'ATTENDED_TRANSFER'

          switch
            when @session.was_connected

              debug "CallHandler: connected call: #{cause} when routing #{gateway.destination_number} through", gateway
              winner = gateway # Winner
              @session.winner = gateway
              # @tag 'answered'

            when @session.was_transferred

              debug "CallHandler: transferred call: #{cause} when routing #{gateway.destination_number} through", gateway
              winner = gateway # Winner
              @session.winner = gateway
              # @tag 'transferred'

            else

              debug "CallHandler: failed call: #{cause} when routing #{gateway.destination_number} through", gateway
              @emit "gateway:#{cause}", gateway
              # No winner yet

However we do not propagate errors, since it would mean interrupting the call sequence. Since we didn't find any winner, we simply return `null`.

        catch error
          debug 'Internal or FreeSwitch error (ignored, skipping to next gateway): ', error.toString()

      if not winner?
        debug "CallHandler: No Route."
        # @tag 'failed'
        await @respond '604'
      else
        debug "CallHandler: the winning gateway was", winner
        @res.winner = winner
        @res.attr winner.attrs

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

codecs

      codecs: 'absolute_codec_string'

Toolbox
-------

    assert = require 'assert'
