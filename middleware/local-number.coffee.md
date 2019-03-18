Local number middleware
=======================

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:local-number"
    {debug} = (require 'tangible') @name

    @include = () ->

      return unless @session?.direction is 'lcr'

      provisioning = new CouchDB (Nimble @cfg).provisioning

      return if @res.finalized()

Used by `astonishing-competition`.

      @session.destination_onnet = false

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
        gw.name = 'local number'
        gw.local_number = true
        gw.carrier = 'LOCAL'
        @session.destination_onnet = true
        null
      .catch (error) =>
        debug "Checking whether #{@destination} is local: #{error.stack ? error}"

Toolbox

    assert = require 'assert'
    url = require 'url'
    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb'
