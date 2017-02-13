Alternate-response middleware
=============================

Mask errors in downstream handling. (Optional. Used by `huge-play`'s `@respond` if present.)

    seem = require 'seem'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:alternate-response"

    @include = ->

      return unless @session.direction is 'lcr'

      @session.alternate_response = seem (response) =>
        @debug 'Response', {response}
        if response.match /^486/
          return @action 'respond', response

        yield @action 'set', 'sip_ignore_remote_cause=true'
        yield @action 'pre_answer'
        yield @action 'sleep', 1000
        yield @action 'respond', '486'
        yield @action 'hangup', 'USER_BUSY'

        @debug 'Response completed'
        return
