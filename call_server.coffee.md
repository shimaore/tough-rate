CallServer
==========

TODO: add Node.js clustering

    module.exports = class CallServer
      constructor: (@port,@options) ->
        assert @options.statistics?, 'Missing `statistics` option.'
        options.respond ?= true
        router = options.router ? new Router options
        @server = FS.server CallHandler router, options
        @options.statistics.info "#{pkg.name} #{pkg.version} starting on port #{port}."
        @server.listen port

      stop: ->
        new Promise (resolve,reject) =>
          try
            @server.close resolve
            delete @server
          catch exception
            reject exception

Toolbox
=======

    pkg = require './package.json'
    FS = require 'esl'
    Promise = require 'bluebird'
    Router = require './router'
    CallHandler = require './call_handler'
    assert = require 'assert'
