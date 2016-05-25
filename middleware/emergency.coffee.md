Emergency Middleware
====================

    find_rule_in = require '../find_rule_in'

Since this code rewrites the destination before resolving gateways, it must be called early on (i.e. after the rule is located but before the gateways are processed).

    class EmergencyMiddlewareError extends Error

    @name = 'tough-rate:middleware:emergency'
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
    @include = ->

      return unless @session.direction is 'lcr'

      provisioning = @cfg.prov

      if not @res.rule?
        debug 'Emergency middleware: no rule is present. (ignored)'
        return
      if not @res.ruleset_database?
        debug 'Emergency middleware: no ruleset_database is present. (ignored)'
        return

Then, see whether the destination number is an emergency number, and process it.

* doc.rule.emergency (boolean) true if the rule is a route for an emergency number. See doc.location and doc.emergency for more information.

      if not @res.rule.emergency
        debug 'Emergency middleware: not an emergency rule.'
        return

      emergency_key = null

* hdr.X-CCNQ3-Routing Emergency Reference. (Obsolete CCNQ3 header.) Key into doc.emergency.
* hdr.X-CCNQ3-Location Emergency location, gets translation into an Emergency Reference (doc.emergency) via doc.location records.
* doc.location Translation of Emergency Locations into Emergency References
* doc.location._id `location:<location-reference>`
* doc.location.routing_data (string) Emergency Reference for this location. Concatenated with the emergency called number to form the key into doc.emergency.

      Promise.resolve true
      .then =>
        emergency_ref = @req.header 'X-CCNQ3-Routing'
        if emergency_ref?
          return emergency_ref

        location_ref = @req.header 'X-CCNQ3-Location'
        if location_ref?
          debug "Locating", {location_ref}
          provisioning.get "location:#{location_ref}"
          .then (doc) ->
            emergency_ref = doc.routing_data
        else
          debug "Neither Routing nor Location info"
          null
      .then (emergency_ref) =>
        debug "Using", {emergency_ref}

        if emergency_ref?
          emergency_key = [@res.destination,emergency_ref].join '#'
        else
          emergency_key = @res.destination

* doc.emergency Emergency Reference document. Translates an Emergency Reference into a called number.
* doc.emergency._id `emergency:<number>#<emergency-reference>` where `number` is the emergency called number (typically a special number such a `330112` to handle national routing), and `emergency-reference` is doc.location.routing_data.
* doc.emergency.destination Translated emergency number.

        provisioning.get "emergency:#{emergency_key}"
      .catch (error) =>
        debug "Emergency record emergency:#{emergency_key} #{error}"
        cuddly.ops "Emergency record emergency:#{emergency_key} #{error}"
        throw error
      .then (doc) =>
        if not doc.destination?
          debug "Emergency middleware: record for `#{emergency_key} has no `destination`."
          cuddly.dev "Emergency middleware: record for `#{emergency_key} has no `destination`."
          throw new EmergencyMiddlewareError "Record for `#{emergency_key} has no `destination`."

The `destination` field in a `emergency` record historically is the target, destination number, not a reference to a `destination` record.

        debug "Emergency middleware: routing call for `#{emergency_key}` to `#{doc.destination}`."

        destinations = doc.destination
        if typeof destinations is 'string'
          destinations = [destinations]

The processing is very distinct based on how many destinations are present.
If only one destination is present, we handle it as a regular call out; the same number is tried on differente gateways in order.

        if destinations.length is 1
          @res.redirect destinations[0]
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

* hdr.X-CCNQ3-Attrs.emergency True if the called number is a translated emergency number.

      .then =>
        @res.attr emergency: true

Toolbox

    assert = require 'assert'
    pkg = require '../package.json'
    Promise = require 'bluebird'
    debug = (require 'debug') "#{pkg.name}:emergency"
    cuddly = (require 'cuddly') "#{pkg.name}:emergency"
