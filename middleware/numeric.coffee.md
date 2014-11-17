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
