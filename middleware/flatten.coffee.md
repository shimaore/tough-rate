Flatten the gateways
====================

    module.exports = ->
      middleware = ->

        @logger.info "Gateways before ops", JSON.stringify @res.gateways

We must flatten the list so that CallHandler can use it.

        @res.gateways = @res.gateways.map (gateway) =>
          if isArray gateway
            gateway.map (gateway) =>
              field_merger {
                default: {destination:@res.destination}
                extra: @res.extra
                gateway
                ruleset:@res.ruleset
                rule:@res.rule
              }
          else
            field_merger {
              default: {destination:@res.destination}
              extra: @res.extra
              gateway
              ruleset:@res.ruleset
              rule:@res.rule
            }

        @logger.info "Gateways after ops", JSON.stringify @res.gateways
        @res.gateways = flatten @res.gateways
        @logger.info "Gateways after flatten", JSON.stringify @res.gateways

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

Toolbox
-------

    flatten = (lists) ->
      result = []
      result = result.concat list for list in lists
      result

    field_merger = require '../field_merger'
    Promise = require 'bluebird'
    {isArray} = require 'util'
    pkg = require '../package.json'
