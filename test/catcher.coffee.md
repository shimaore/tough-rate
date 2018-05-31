    @name = 'test/catcher'
    @include = ->

      return unless @data['Channel-Context'] is 'answer'

      await @action 'answer'
      await @action 'sleep', 1000
      await @action 'hangup'
