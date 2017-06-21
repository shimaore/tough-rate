    pkg = require '../package'
    @name = "#{pkg.name}:middleware:post-send"

    @include = ->

      return unless @session.direction is 'lcr'

      @debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction
      @call.emit 'tough-rate-hangup'

      if @session.skip_lcr_hangup
        @debug 'Skip LCR hangup.'
        return

      if @session.was_transferred
        @debug 'Session was transferred'
        return

The only post-call action currently is to hangup the call.

      @debug 'hangup'
      @tag 'hangup'
      @action 'hangup'
