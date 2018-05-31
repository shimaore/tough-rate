    pkg = require '../package'
    @name = "#{pkg.name}:middleware:format-matcher"

    plans = require 'numbering-plans'

    @include = ->

      return unless @session?.direction is 'lcr'

      switch data = plans.validate @destination
        when true
          return
        when false
          await @respond '484'
        when null
          return
        else
          @session.destination_information = data
          await @set
            initial_callee_id_name: data.full_name
            origination_callee_id_name: data.full_name

      return
