Longest-match rule lookup
=========================

    debug = (require 'tangible') 'tough-rate:find_rule_in'
    merge = require './field_merger'

    find = (destination,database,key) ->
      ids = ("#{key}:#{destination[0...l]}" for l in [0..destination.length]).reverse()
      rows = database.queryStream null, '_all_docs', keys:ids, include_docs: true
      rule = null
      for await row from rows
        if row.doc? and not row.doc.disabled
          rule ?= row.doc
      rule

    find_rule_in = (destination,database,key = 'prefix') ->
      debug 'find rule in', destination

      rule = await find destination, database, key

Lookup the `destination` if any.

* doc.prefix.destination (string) doc.destination identifier for the rule. If present, it is used instead of the prefix record.
* doc.destination Destination for a doc.rule.
* doc.destination._id "destination:{destination}"
* doc.destination.gwlist (array) List of gateways/carriers for this destination.

      if rule?.destination?
        debug 'destination', rule.destination
        destination = await database.get "destination:#{rule.destination}"

        if destination?
          debug 'merging', {rule,destination}
          rule = merge [rule,destination]
        else
          rule = null

      debug 'rule', rule
      rule

    module.exports = find_rule_in
