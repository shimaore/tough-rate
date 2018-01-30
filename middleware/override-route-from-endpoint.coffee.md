Override route based on original (client-side) endpoint
=======================================================

This is a dedicated bit of code that should be inserted before `ruleset` to force a specific route based on the originating endpoint.

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:override-route-from-endpoint"
    @init = ->
      assert @cfg.prov?, 'Missing `prov`'
    @include = ->

      return unless @session?.direction is 'lcr'

      provisioning = @cfg.prov

      return if @res.finalized()

      endpoint = (@req.header 'X-Ex')?.match(/^\w+ \S+ \d+ -> \S+ \d+ (\S+)/)?[1]

      return unless endpoint?

      provisioning.get "endpoint:#{endpoint}"
      .then (doc) =>
        if doc.global_route?
          @clear()
          @res.attempt doc.global_route
      .catch (error) =>
        @debug "Override-route-from-endpoint: #{error}"
