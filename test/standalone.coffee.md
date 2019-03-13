    @name = 'test/standalone'
    @include = ->
      @session.direction = 'lcr'
      @session.emergency_location = @data.variable_location
      @session.emergency_location ?= @data['variable_sip_h_X-Bear']
      @reference =
        add_tag: ->
        get_in: -> Promise.resolve []
        get_number_domain: -> Promise.resolve()
        get_endpoint: -> Promise.resolve()
