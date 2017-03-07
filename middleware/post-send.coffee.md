    @name = "tough-rate:middleware:post-send"

    @include = ->

      return unless @session.direction is 'lcr'

      @debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction

The only post-call action currently is to hangup the call.
FIXME: This does not belong here, since this code gets executed immediately after the call is connected.

      ###
      unless @session.was_transferred
        @action 'hangup'
      ###
