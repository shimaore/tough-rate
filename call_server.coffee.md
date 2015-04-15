CallServer
==========

TODO: add Node.js clustering

    module.exports = class CallServer extends UsefulWindCallServer
      constructor: (@port,@options) ->
        # `host` is not required (carrier-id will simply not sort using it if it's not present).
        for name in 'provisioning sip_domain_name ruleset_of profile'.split ' '
          assert @options[name]?, "CallServer: options.#{name} is required"
        @statistics = @options.statistics ? new CaringBand()

        @gateway_manager = new GatewayManager @options.provisioning, @options.sip_domain_name

        @gateway_manager.init()
        .catch (error) =>
          debug "CallServer startup error: Gateway Manager failed: #{error}, bailing out."
          throw error
        .then =>
          super {@options,@gateway_manager,@statistics}
          assert @cfg?
          @router.use './middleware/setup'
          modules = @options.use ? included_middlewares
          @use module for module in modules
          @listen @port
        .catch (error) =>
          debug "CallServer runtime error: #{error}"

      use: (module, router = @router) ->
        if module in included_middlewares
          module = "./middleware/#{module}"

        router.use module

    included_middlewares = [
      'numeric'
      'response-handlers'
      'local-number'
      'ruleset'
      'emergency'
      'routes-gwid'
      'routes-carrierid'
      'routes-registrant'
      'flatten'
      'cdr'
      'call-handler'
      'use-ccnq-to-e164'
    ]

Toolbox
=======

    pkg = require './package.json'
    FS = require 'esl'
    Promise = require 'bluebird'
    GatewayManager = require './gateway_manager'
    CaringBand = require 'caring-band'
    debug = (require 'debug') "#{pkg.name}:call_server"
    assert = require 'assert'
