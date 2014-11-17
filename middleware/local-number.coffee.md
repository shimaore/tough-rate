Local number middleware
=======================

    module.exports = (provisioning) ->
      assert provisioning, 'Missing `provisioning`.'

      middleware = ->
        return if @finalized()

        @logger.info "Checking whether #{@destination} is local."
        provisioning.get "number:#{@destination}"
        .then (doc) =>
          @sendto doc.inbound_uri
        .catch (error) =>
          @logger.info "Checking whether #{@destination} is local:", error

Toolbox

    assert = require 'assert'
