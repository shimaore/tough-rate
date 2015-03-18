    module.exports = ->
      middleware = ->
        @logger.info "Forcing #{@data.variable_ccnq_to_e164}"
        @destination = @data.variable_ccnq_to_e164
        return

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

    pkg = require '../package.json'
