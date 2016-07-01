    seem = require 'seem'
    pkg = require '../package'
    @name = "#{pkg.name}:middleware:format-matcher"
    debug = (require 'debug') @name

    plans = require 'numbering-plans'

    @include = seem ->

      return unless @session.direction is 'lcr'

      switch data = plans.validate @destination
        when true
          return
        when false
          yield @respond '484'
        when null
          return
        else
          @session.destination_information = data
          yield @set
            initial_callee_id_name: data.full_name
            origination_callee_id_name: data.full_name

      return
