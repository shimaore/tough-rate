    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:use-ccnq-to-e164"
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

      debug "Forcing #{@data.variable_ccnq_from_e164} -> #{@data.variable_ccnq_to_e164}"
      @source      = @data.variable_ccnq_from_e164
      @destination = @data.variable_ccnq_to_e164
      return
