    @name = 'test/standalone'
    @include = ->
      @session.direction = 'lcr'
      @debug = (require 'tangible') 'tests'
