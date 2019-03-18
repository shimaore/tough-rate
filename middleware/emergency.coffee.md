Emergency Middleware
====================

    find_rule_in = require '../find_rule_in'

Since this code rewrites the destination before resolving gateways, it must be called early on (i.e. after the rule is located but before the gateways are processed).

    class EmergencyMiddlewareError extends Error

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:emergency"
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

Used by `astonishing-competition`.

      @session.destination_emergency = false

      provisioning = new CouchDB (Nimble @cfg).provisioning

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

* doc.location Translation of Emergency Locations into Emergency References
* doc.location._id `location:<location-reference>`
* doc.location.routing_data (string) Emergency Reference for this location. Concatenated with the emergency called number to form the key into doc.emergency.

Normally we should be provided with the emergency reference.
If it isn't present, we try to retrieve it from the location reference.

      @session.destination_emergency = true

      emergency_ref = @session.emergency_ref
      location_ref = @session.emergency_location

      {source_number,destination_number} = @res.rule

      if not emergency_ref? and location_ref?
        debug "Locating", {location_ref}
        doc = await provisioning
          .get "location:#{location_ref}"
          .catch (error) =>
            debug.dev "Could not locate #{location_ref}, call from #{source_number} to #{destination_number}: #{error.stack ? error}"
            {}
        emergency_ref = doc.routing_data

If the location provides an asserted-number, use it instead of the local-number's or endpoint's `asserted_number`.
This overrides the value set in `huge-play/middleware/client/egress/post.coffee.md`.
* doc.location.number (string, optional) The global-number associated with this emergency location, if any. When present, overrides the default doc.local_number.asserted_number or doc.src_endpoint.asserted_number when placing an emergency call.

        if doc.number?
          source_number = doc.number

      debug "Using", {emergency_ref,source_number,destination_number}

      if emergency_ref?
        emergency_key = [destination_number,emergency_ref].join '#'
      else
        emergency_key = destination_number

* doc.emergency Emergency Reference document. Translates an Emergency Reference into a called number.
* doc.emergency._id `emergency:<number>#<emergency-reference>` where `number` is the emergency called number (typically a special number such a `33_112` to handle national routing), and `emergency-reference` is doc.location.routing_data.
* doc.emergency.destination (string or array of strings) Translated emergency number(s).

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

Final processing: gather all possible gateways

      @res.rule = {source_number}
      gwlists = []
      max_len = 0

We will try each number in order (round-robin) until we run out of gateways.

      for destination in destinations
        {gwlist} = await find_rule_in destination, @res.ruleset_database, @res.ruleset.key
        max_len = gwlist.length if gwlist.length > max_len
        gwlists.push gwlist.map (gw) -> Object.assign gw, destination_number: destination

      debug 'gwlists', gwlists

      @res.gateways = []
      for i in [0...max_len]
        for gwlist in gwlists when gwlist.length >= i
          @res.gateways.push gwlist[i]

      debug 'res.gateways', @res.gateways

* hdr.X-At.emergency True if the called number is a translated emergency number.

      @res.attr emergency: true

Toolbox

    assert = require 'assert'
    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb'
