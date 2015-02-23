CallServer
==========

TODO: add Node.js clustering

    module.exports = class CallServer
      constructor: (@port,@options) ->
        # `host` is not required (carrier-id will simply not sort using it if it's not present).
        for name in 'provisioning sip_domain_name ruleset_of profile logger'.split ' '
          assert @options[name]?, "CallServer: options.#{name} is required"
        @logger = @options.logger
        @statistics = @options.statistics
        if not @statistics?
          CaringBand = require 'caring-band'
          @statistics = new CaringBand()

        @gateway_manager = new GatewayManager @options.provisioning, @options.sip_domain_name, @logger
        router = @options.router ? @default_router @options.use
        @server = FS.server ->
          router.route this
        @logger.info "CallServer #{pkg.name} #{pkg.version} starting on port #{@port}."

        @gateway_manager.init()
        .then =>
          @server.listen @port
        .catch (error) =>
          @logger.error "CallServer runtime error: #{error}"

      stop: ->
        new Promise (resolve,reject) =>
          try
            @server.close resolve
            delete @server
          catch exception
            reject exception

      use: (module, router = @router) ->
        if module in included_middlewares
          module = "./middleware/#{module}"

        mw = if typeof module is 'string'
              @logger.info "CallServer: loading middleware `#{module}`."
              (require module).call this, router
            else
              @logger.info "CallServer: loading middleware."
              module.call this, router
        router.use mw

      default_router: (use, router) ->
        use ?= included_middlewares
        router ?= new Router @logger, @statistics
        @use module, router for module in use
        router

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
    ]

Toolbox
=======

    pkg = require './package.json'
    FS = require 'esl'
    Promise = require 'bluebird'
    Router = require './router'
    GatewayManager = require './gateway_manager'
    assert = require 'assert'
