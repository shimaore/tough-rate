    module.exports = ->
      middleware = ->
        debug "Forcing #{@data.variable_ccnq_to_e164}"
        @destination = @data.variable_ccnq_to_e164
        return

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:use-ccnq-to-e164"
