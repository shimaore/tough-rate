Local number middleware
=======================

    module.exports = () ->
      provisioning = @options.provisioning
      assert provisioning, 'Missing `provisioning`.'
      domain = @options.sip_domain_name

      middleware = ->
        return if @finalized()

        @logger.info "Checking whether #{@destination} is local."
        provisioning.get "number:#{@destination}"
        .then (doc) =>
          return if doc.disabled

          gw = @sendto doc.inbound_uri
          if domain? and doc.account?
            gw.headers =
              'P-Charge-Info': url.format {
                protocol:'sip'
                auth: doc.account
                hostname: domain
              }
          null
        .catch (error) =>
          @logger.info "Checking whether #{@destination} is local: #{error}"

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename} for #{domain}"
      return middleware

Toolbox

    assert = require 'assert'
    url = require 'url'
    pkg = require '../package.json'
