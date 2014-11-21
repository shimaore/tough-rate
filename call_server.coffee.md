CallServer
==========

TODO: add Node.js clustering

    module.exports = class CallServer
      constructor: (@port,@options) ->
        # `host` is not required (carrier-id will simply not sort using it if it's not present).
        for name in 'provisioning sip_domain_name ruleset_of profile'.split ' '
          assert @options[name]?, "CallServer: options.#{name} is required"
        @logger = @options.logger ? require 'winston'

        @gateway_manager = new GatewayManager @options.provisioning, @options.sip_domain_name, @logger
        router = @options.router ? @default_router @options.use
        @server = FS.server ->
          router.route this
        @logger.info "#{pkg.name} #{pkg.version} starting on port #{port}."

        @gateway_manager.init()
        .then =>
          @server.listen port

      stop: ->
        new Promise (resolve,reject) =>
          try
            @server.close resolve
            delete @server
          catch exception
            reject exception

      use: (module, router = @router) ->
        switch module
          when 'numeric'
            router.use (require './middleware/numeric')()
          when 'response-handlers'
            router.use (require './middleware/response-handlers') @gateway_manager
          when 'local-number'
            router.use (require './middleware/local-number') @options.provisioning
          when 'ruleset'
            router.use (require './middleware/ruleset') @options.provisioning,@options.ruleset_of,@options.default_outbound_route
          when 'emergency'
            router.use (require './middleware/emergency') @options.provisioning
          when 'routes-gwid'
            router.use (require './middleware/routes-gwid') @gateway_manager
          when 'routes-carrierid'
            router.use (require './middleware/routes-carrierid') @gateway_manager, @options.host
          when 'routes-registrant'
            router.use (require './middleware/routes-registrant') @options.provisioning
          when 'flatten'
            router.use (require './middleware/flatten')()
          when 'call-handler'
            router.use (require './middleware/call-handler') @options.profile
          else
            if typeof module is 'string'
              (require module).call this, router
            else
              module.call this, router

      default_router: (use, router) ->
        use ?= [
          'numeric'
          'response-handlers'
          'local-number'
          'ruleset'
          'emergency'
          'routes-gwid'
          'routes-carrierid'
          'routes-registrant'
          'flatten'
          'call-handler'
        ]
        router ?= new Router @logger
        @use module, router for module in use
        router

Toolbox
=======

    pkg = require './package.json'
    FS = require 'esl'
    Promise = require 'bluebird'
    Router = require './router'
    GatewayManager = require './gateway_manager'
    assert = require 'assert'
