Emergency Middleware
====================

    find_rule_in = require '../find_rule_in'

Since this code rewrites the destination before resolving gateways, it must be called early on (i.e. after the rule is located but before the gateways are processed).

    module.exports = ->
      provisioning = @options.provisioning
      assert provisioning, 'Missing `provisioning`.'

      middleware = ->

        if not @res.rule?
          @logger.error 'Emergency middleware: no rule is present. (ignored)'
          return
        if not @res.ruleset_database?
          @logger.error 'Emergency middleware: no ruleset_database is present. (ignored)'
          return

Then, see whether the destination number is an emergency number, and process it.

        if not @res.rule.emergency
          @logger.info 'Emergency middleware: not an emergency rule.'
          return

        emergency_ref = @req.header 'X-CCNQ3-Routing'

        if emergency_ref?
          emergency_key = [@res.destination,emergency_ref].join '#'
        else
          emergency_key = @res.destination

        provisioning.get "emergency:#{emergency_key}"
        .catch (error) =>
          @logger.error "Emergency record emergency:#{emergency_key}", error
          throw error
        .then (doc) =>
          if not doc.destination?
            @logger.error "Emergency middleware: record for `#{emergency_key} has no `destination`."
            throw new EmergencyMiddlewareError "Record for `#{emergency_key} has no `destination`."

The `destination` field in a `emergency` record historically is the target, destination number, not a reference to a `destination` record.

          @logger.info "Emergency middleware: routing call for `#{emergency_key}` to `#{doc.destination}`."

          destinations = doc.destination
          if typeof destinations is 'string'
            destinations = [destinations]

The processing is very distinct based on how many destinations are present.
If only one destination is present, we handle it as a regular call out; the same number is tried on differente gateways in order.

          if destinations.length is 1
            @redirect destinations[0]
            find_rule_in destinations[0], @res.ruleset_database
            .then (rule) =>
              @res.gateways = rule.gwlist
              delete rule.gwlist
              @res.rule = rule

If multiple destination numbers are present, we cannot afford to try all combinations of (numbers x gateways). We only try the first gateway for each number.

          else
            Promise.all destinations.map (destination) =>
              find_rule_in destination, @res.ruleset_database
              .then (rule) ->
                gw = rule.gwlist[0]
                gw.destination_number = destination
                gw
            .then (gateways) =>
              @res.gateways = gateways
              @res.rule = {}

        .then =>
          @attr emergency: true

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      return middleware

Toolbox

    assert = require 'assert'
    pkg = require '../package.json'
    Promise = require 'bluebird'
