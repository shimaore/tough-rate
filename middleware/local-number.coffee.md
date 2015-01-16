Local number middleware
=======================

    module.exports = () ->
      provisioning = @options.provisioning
      assert provisioning, 'Missing `provisioning`.'

      middleware = ->
        return if @finalized()

        @logger.info "Checking whether #{@destination} is local."
        provisioning.get "number:#{@destination}"
        .then (doc) =>
          @sendto doc.inbound_uri
        .catch (error) =>
          @logger.info "Checking whether #{@destination} is local:", error

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

Toolbox

    assert = require 'assert'
    pkg = require '../package.json'
