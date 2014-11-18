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
        router = @options.router ? @default_router()
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

      default_router: ->
        router = new Router @logger
        find_rule_in = require './middleware/ruleset'
        router.use (require './middleware/numeric')()
        router.use (require './middleware/response-handlers') @gateway_manager
        router.use (require './middleware/local-number') @options.provisioning
        router.use (require './middleware/ruleset') @options.provisioning,@options.ruleset_of,@options.default_outbound_route
        router.use (require './middleware/emergency') @options.provisioning
        router.use (require './middleware/routes-gwid') @gateway_manager
        router.use (require './middleware/routes-carrierid') @gateway_manager, @options.host
        router.use (require './middleware/routes-registrant') @options.provisioning
        router.use (require './middleware/flatten')()
        router.use (require './middleware/call-handler') @options.profile
        router

Toolbox
=======

    pkg = require './package.json'
    FS = require 'esl'
    Promise = require 'bluebird'
    Router = require './router'
    GatewayManager = require './gateway_manager'
    assert = require 'assert'
