    @name = 'numeric'
    @include = ->
      unless @source? and @source.match /^\d+$/
        @respond '484'
        debug 'Missing or invalid source', @data
        return

      unless @destination? and @destination.match /^[\d#*]+$/
        @respond '484'
        debug 'Missing or invalid destination', @data
        return

    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:numeric"
