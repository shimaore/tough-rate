Emergency Middleware
====================

    find_rule_in = require '../find_rule_in'

Since this code rewrites the destination before resolving gateways, it must be called early on (i.e. after the rule is located but before the gateways are processed).

    class EmergencyMiddlewareError extends Error

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:emergency"
    {debug} = (require 'tangible') @name
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
    @include = ->

      return unless @session?.direction is 'lcr'

      provisioning = @cfg.prov

      if not @res.rule?
        debug 'Emergency middleware: no rule is present. (ignored)'
        return
      if not @res.ruleset_database?
        debug 'Emergency middleware: no ruleset_database is present. (ignored)'
        return

Then, see whether the destination number is an emergency number, and process it.

* doc.prefix.emergency (boolean) true if the rule is a route for an emergency number. See doc.location and doc.emergency for more information.
* doc.destination.emergency (boolean) true if the rule is a route for an emergency number. See doc.location and doc.emergency for more information.

      if not @res.rule.emergency
        debug 'Emergency middleware: not an emergency rule.'
        return

      # @tag 'emergency'

* doc.location Translation of Emergency Locations into Emergency References
* doc.location._id `location:<location-reference>`
* doc.location.routing_data (string) Emergency Reference for this location. Concatenated with the emergency called number to form the key into doc.emergency.

Normally we should be provided with the emergency reference.
If it isn't present, we try to retrieve it from the location reference.

      @session.destination_emergency = true

      emergency_ref = @session.emergency_ref
      location_ref = @session.emergency_location

      if not emergency_ref? and location_ref?
        debug "Locating", {location_ref}
        doc = await provisioning
          .get "location:#{location_ref}"
          .catch (error) =>
            debug.dev "Could not locate #{location_ref}, call from #{@source} to #{@destination}: #{error.stack ? error}"
            {}
        emergency_ref = doc.routing_data

      debug "Using", {emergency_ref,@source,@destination}

      if emergency_ref?
        emergency_key = [@res.destination,emergency_ref].join '#'
      else
        emergency_key = @res.destination

* doc.emergency Emergency Reference document. Translates an Emergency Reference into a called number.
* doc.emergency._id `emergency:<number>#<emergency-reference>` where `number` is the emergency called number (typically a special number such a `330112` to handle national routing), and `emergency-reference` is doc.location.routing_data.
* doc.emergency.destination Translated emergency number.

      doc = await provisioning
        .get "emergency:#{emergency_key}"
        .catch (error) ->
          {}

      if not doc.destination?
        debug.dev "Emergency middleware: record for `#{emergency_key} has no `destination`."
        return

The `destination` field in a `emergency` record historically is the target, destination number, not a reference to a `destination` record.

      debug "Emergency middleware: routing call for `#{emergency_key}` to `#{doc.destination}`."

      destinations = doc.destination
      if typeof destinations is 'string'
        destinations = [destinations]

The processing is very distinct based on how many destinations are present.
If only one destination is present, we handle it as a regular call out; the same number is tried on differente gateways in order.

      if destinations.length is 1
        destination = destinations[0]
        @res.redirect destination
        rule = await find_rule_in destination, @res.ruleset_database, @res.ruleset.key
        @res.gateways = rule.gwlist
        delete rule.gwlist
        @res.rule = rule

If multiple destination numbers are present, we cannot afford to try all combinations of (numbers x gateways). We only try the first gateway for each number.

      else
        gateways = []
        for destination in destinations
          rule = await find_rule_in destination, @res.ruleset_database, @res.ruleset.key
          gw = rule.gwlist[0]
          gw.destination_number = destination
          gateways.push gw
        @res.gateways = gateways
        @res.rule = {}

* hdr.X-At.emergency True if the called number is a translated emergency number.

      @res.attr emergency: true

Toolbox

    assert = require 'assert'
