Local number middleware
=======================

    module.exports = () ->
      provisioning = @cfg.options.provisioning
      assert provisioning, 'Missing `provisioning`.'
      domain = @cfg.options.sip_domain_name

      middleware = ->
        return if @finalized()

        debug "Checking whether #{@destination} is local."
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
          debug "Checking whether #{@destination} is local: #{error}"

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename} for #{domain}"
      middleware.call this

Toolbox

    assert = require 'assert'
    url = require 'url'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:local-number"
