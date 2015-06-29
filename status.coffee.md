Status
======

A status-monitoring object that can be in any of three states:
- active
- suspicious
- faulty

Moves from active to suspicious or faulty based on trigger.
Moves from suspicious to faulty if at least `suspicious_limit` triggers are reported in a `suspicious_timeout` period.
Moves from suspicious to active if no triggers are reported in a `suspicious_timeout` period.
Stays in faulty state for at least `faulty_timeout` and downgrades to suspicious at the end of the period if no other faulty triggers have been reported.

    second = 1000

    {EventEmitter} = require 'events'

    module.exports = class Status extends EventEmitter
      constructor: ->
        @state = 'active'
        @_timer = null
        @_interval = null
        @reported = 0

      stop: ->
        clearTimeout @_timer if @_timer?
        @_timer = null
        clearInterval @_interval if @_interval?
        @_interval = null
        @emit 'stop'
        return

      mark_as_faulty: ->

We will reset any pending timer.

        if @_timer?
          clearTimeout @_timer
          @_timer = null

        @state = 'faulty'

Once the timeout has expired, downgrade to suspicious state.

        clear = =>
          @_timer = null
          @state = 'suspicious'
          @mark_as_suspicious()

Reset the timer.

        @_timer = setTimeout clear, @faulty_timeout

        @emit 'faulty'
        return

      mark_as_suspicious: ->

Count how many times we got those.

        @reported++

Do not downgrade.

        return if @state is 'faulty'

        @state = 'suspicious'

Upgrade to faulty if we reached the limit.

        if @reported >= @suspicious_limit
          @reported = 0
          @mark_as_faulty()
          return

Never downgrade from 'faulty' when expiring suspicious.

        test = =>

Downgrade from suspicious only if none was reported since.

          if @state is 'suspicious' and @reported is 0
            @state = 'active'
            clearInterval @_interval
            @_interval = null
            @emit 'active'

Reset the error counter for the next run.

          @reported = 0

Make sure only one interval timer is set.

        if not @_interval?
          @_interval = setInterval test, @suspicious_timeout

        @emit 'suspicious'
        return

      faulty_timeout: 15*second
      suspicious_timeout: 15*second
      suspicious_limit: 5
