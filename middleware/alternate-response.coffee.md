Alternate-response middleware
=============================

Mask errors in downstream handling. (Optional. Used by `huge-play`'s `@respond` if present.)

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:alternate-response"
    {debug} = (require 'tangible') @name

    @include = ->

      return unless @session?.direction is 'lcr'

      @session.alternate_response = (response) =>
        debug 'Response', {response}
        if response.match /^486/
          return @action 'respond', response

        await @action 'set', 'sip_ignore_remote_cause=true'
        await @action 'pre_answer'
        await @action 'sleep', 1000
        await @action 'respond', '486'
        await @action 'hangup', 'USER_BUSY'

        debug 'Response completed'
        return
