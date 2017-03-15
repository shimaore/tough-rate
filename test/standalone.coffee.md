    @name = 'test/standalone'
    @include = ->
      @session.direction = 'lcr'
      d = (args...) -> console.log args[0], args[1...].map (x) -> JSON.stringify x
      d.dev = d.csr = d.ops = d
      # @debug = d
