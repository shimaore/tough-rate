    pkg = require '../package'
    @name = "#{pkg.name}:middleware:client:egress:post-send"

    @include = ->

      return unless @session.direction is 'lcr'

      @debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction

The only post-call action currently is to hangup the call.

      unless @session.was_transferred
        @action 'hangup'
