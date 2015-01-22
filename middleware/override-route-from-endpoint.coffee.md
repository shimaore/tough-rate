Override route based on original (client-side) endpoint
=======================================================

This is a dedicated bit of code that should be inserted before `ruleset` to force a specific route based on the originating endpoint.

    module.exports = ->
      provisioning = @options.provisioning
      assert provisioning, 'Missing `provisioning`'

      middleware = ->
        return if @finalized()

        endpoint = (@req.header 'X-CCNQ3-Extra')?.match(/^\w+ \S+ \d+ -> \S+ \d+ (\S+)/)?[1]

        return unless endpoint?

        provisioning.get "endpoint:#{endpoint}"
        .then (doc) =>
          if doc.global_route?
            @clear()
            @attempt doc.global_route
        .catch (error) =>
          @logger.error "Override-route-from-endpoint: #{error}"


      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

    pkg = require '../package.json'
