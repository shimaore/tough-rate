Local number middleware
=======================

    @name = 'local-number'
    @include = () ->
      provisioning = @cfg.options.provisioning
      assert provisioning, 'Missing `provisioning`.'
      domain = @cfg.options.sip_domain_name

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

Toolbox

    assert = require 'assert'
    url = require 'url'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:local-number"
