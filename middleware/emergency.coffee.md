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
          @redirect doc.destination
          find_rule_in doc.destination, @res.ruleset_database
        .then (rule) =>
          @res.gateways = rule.gwlist
          delete rule.gwlist
          @res.rule = rule

Toolbox

    assert = require 'assert'
