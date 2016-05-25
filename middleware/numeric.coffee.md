    @name = 'numeric'
    @include = ->

      return unless @session.direction is 'lcr'

      unless @source? and @source.match /^\d+$/
        debug 'Missing or invalid source', @data
        @res.respond '484'
        return

      unless @destination? and @destination.match /^[\d#*]+$/
        debug 'Missing or invalid destination', @data
        @res.respond '484'
        return

    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:numeric"
