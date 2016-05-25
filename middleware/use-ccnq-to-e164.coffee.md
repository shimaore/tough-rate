    @name = 'use-ccnq-to-e164'
    @include = ->

      return unless @session.direction is 'lcr'

      debug "Forcing #{@data.variable_ccnq_from_e164} -> #{@data.variable_ccnq_to_e164}"
      @source      = @data.variable_ccnq_from_e164
      @destination = @data.variable_ccnq_to_e164
      return

    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:use-ccnq-to-e164"
