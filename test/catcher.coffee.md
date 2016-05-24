    seem = require 'seem'
    @include = seem ->

      return unless @data['Channel-Context'] is 'answer'

      yield @action 'answer'
      yield @action 'sleep', 1000
      yield @action 'hangup'
