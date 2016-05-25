Local number middleware
=======================

    @name = 'tough-rate:middleware:local-number'
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
    @include = () ->

      return unless @session.direction is 'lcr'

      provisioning = @cfg.prov

      return if @res.finalized()

      debug "Checking whether #{@destination} is local."
      provisioning.get "number:#{@destination}"
      .then (doc) =>
        if doc.disabled
          debug "#{doc._id} is local but is disabled."
          return
        if not doc.account?
          debug "#{doc._id} is local but has no account."
          return

        gw = @res.sendto doc.inbound_uri
        gw.headers =
          'P-Charge-Info': url.format {
            protocol:'sip:'
            auth: doc.account
            hostname: @cfg.sip_domain_name ? @cfg.host ? 'local'
          }
        null
      .catch (error) =>
        debug "Checking whether #{@destination} is local: #{error}"

Toolbox

    assert = require 'assert'
    url = require 'url'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:local-number"
