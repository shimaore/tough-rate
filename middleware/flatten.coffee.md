Flatten the gateways
====================

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:flatten"
    @include = ->

      return unless @session.direction is 'lcr'

      @debug "Gateways before ops", @res.gateways

      unless @res.gateways?
        @debug 'No gateways'
        return

We must flatten the list so that CallHandler can use it.

      @res.gateways = @res.gateways.map (gateway) =>
        if isArray gateway
          gateway.map (gateway) =>
            field_merger [
              {destination:@res.destination}
              @res.extra
              gateway
              @res.ruleset
              @res.rule
            ]
        else
          field_merger [
            {destination:@res.destination}
            @res.extra
            gateway
            @res.ruleset
            @res.rule
          ]

      @debug "Gateways after ops", @res.gateways
      @res.gateways = flatten @res.gateways
      @debug "Gateways after flatten", @res.gateways
      return

Toolbox
-------

    flatten = (lists) ->
      result = []
      result = result.concat list for list in lists
      result

    field_merger = require '../field_merger'
    {isArray} = require 'util'
