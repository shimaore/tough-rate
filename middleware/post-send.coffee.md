    pkg = require '../package'
    @name = "#{pkg.name}:middleware:post-send"

    @include = ->

      return unless @session.direction is 'lcr'

      @debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction

      if @session.skip_lcr_hangup
        @debug 'Skip LCR hangup.'
        return

The only post-call action currently is to hangup the call.

      @debug 'hangup'
      @action 'hangup'
