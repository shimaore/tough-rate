Override route based on original (client-side) endpoint
=======================================================

This is a dedicated bit of code that should be inserted before `ruleset` to force a specific route based on the originating endpoint.

    module.exports = ->
      provisioning = @cfg.options.provisioning
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
          debug "Override-route-from-endpoint: #{error}"


      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:override-route-from-endpoint"
