    module.exports = ->
      middleware = ->
        unless @source? and @source.match /^\d+$/
          @respond '484'
          @logger.warn 'Missing or invalid source', @data
          return

        unless @destination? and @destination.match /^[\d#*]+$/
          @respond '484'
          @logger.warn 'Missing or invalid destination', @data
          return

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

    pkg = require '../package.json'
