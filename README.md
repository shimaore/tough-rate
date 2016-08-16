About
=====

`tough-rate` is a Least Cost Routing (LCR) application for FreeSwitch.

It runs under Node.js and uses CouchDB for provisioning.

It is part of the [CCNQ SoftSwitch](http://ccnq.shimaore.net/).

Usage
=====

You might want to look into the [matching docker image](https://github.com/shimaore/docker.tough-rate) which includes supervisord and FreeSwitch; its [server script](https://github.com/shimaore/docker.tough-rate/blob/master/server.coffee.md) demonstrates how to use this package.

Note that the present package's `CallServer` module provides a default router equivalent using the following middleware:

    ./middleware/numeric
    ./middleware/response-handlers
    ./middleware/local-number
    ./middleware/ruleset
    ./middleware/emergency
    ./middleware/routes-gwid
    ./middleware/routes-carrierid
    ./middleware/routes-registrant
    ./middleware/flatten
    ./middleware/call-handler

Controlling Records
===================

Gateway Attributes
------------------

The following parameters are common to all gateways, they might be inserted by carrier records, gateways definitions, rulesets, destination, individual rules, or individual item in a `gwlist`.
They are all optional.

    disabled          (default false)
    progress_timeout  (default 4)  from invite to progress (180, 183, ...) - maximum post-dial-delay
    answer_timeout    (default 90) from progress to answer (200) - maximum ringback time
    dialog_timeout    (default 28800) from answer to end - maximum call duration
    attrs             (default {})

The following attributes are available as well, but generally not defined at the gateway level:

    priority          (default: 0 for the last gateway in a list, 1 for the previous one, etc.)
    local_gateway_extra_priority (default 0.5)  added to priority if the gateway is on the same host
    weight            (default 1, must be > 0)
    gwlist            (default [])

Different attribute values might be present. They are always resolved in the following order: default, carrier, gateway, ruleset, destination, rule, gwlist entry.

The values in `attrs` are merged, the most specific value is kept.
The values for `disabled` are ORed so that any item disabled in the list will disable.

gateway (individual gateway records)
------------------------------------

    _id: "gateway:#{sip_domain_name}:#{gwid}"
    type: 'gateway'

    sip_domain_name
    gwid
    address           (required) "#{ip}:#{host}", DNS name
    carrierid         (optional)

    disabled
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs

gateway (as part of host)
-------------------------

Gateways are defined inside `sip_profiles`; the following fields are available inside a given `sip_profiles` entry:

    egress.gwid
    egress.carrierid

    egress.disabled
    egress.progress_timeout
    egress.answer_timeout
    egress.dialog_timeout
    egress.attrs

The following gateway fields do not need to be specified:
- `address` is computed based on the profile's data;
- `sip_domain_name` is taken from the host.

carrier
-------

A carrier offers one or more gateways.

A carrier is indicated alongside a gateway definition, either inside a `gateway` record, or in the `sip_profiles` part of a host definition.

A carrier record might optionally be created to provide carrier-wide default values for the gateways listed under that carrier.

    _id: "carrier:{sip_domain_name}:{carrierid}"
    type: 'carrier'

    sip_domain_name
    carrierid
    try (default 1, must be > 0)

    local_gateway_extra_priority
    disabled
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs

ruleset
-------

Rulesets records are found in the main provisioning database.

    _id: "ruleset:#{sip_domain_name}:#{groupid}"
    type: 'ruleset'
    sip_domain_name
    groupid
    title
    description
    database

    disabled
    attrs

The title is the name shown in the management tools.
The description is a longer description of what this ruleset is about.
The database indicates the name of the database used to store the ruleset.

Rules
=====

Rules are defined in a ruleset database. There is one ruleset database per ruleset.

The gwlist is converted into a list of gateways as follows:
- Each record in the list is assigned an additional priority, starting from 0 for the last item in the list and adding 1 going backwards in the list.
- Records which have a `carrierid` and no `gwid` are replaced with a list of the gateways for that carrierid, up to `try` entries. The value of `try` defaults to the number of gateways for that carrier. Gateways are selected using weighted round-robin.
- Records which have a `gwid` are gateways. Other records are rejected.
- Any gateway local to the host receives an additional `local_gateway_priority` (by default 0.5).
- In the resulting list, gateways are sorted by descending priority if no `weight` field is present.

destination
-----------

A destination record might be referenced by a prefix in order to provide values for that prefix.

    _id: "destination:#{destination}"
    type: 'destination'
    destination: destination

    disabled

    gwlist: [
      {gwid, weight, attrs,...}
      {carrierid, weight, try, attrs,...}
    ]

    progress_timeout
    answer_timeout
    dialog_timeout
    attrs

`prefix` record
---------------

Prefixes are first looked-up in `prefix` records:

    _id: "prefix:{prefix}"
    type: 'prefix'
    prefix: "{prefix}"

    disabled

    destination: "{destination}"

Sometimes it is more convenient to store data directly inside the prefix:

    _id: "prefix:{prefix}"
    type: 'prefix'
    prefix: "{prefix}"

    gwlist: [
      {gwid, weight, attrs,...}
      {carrierid, weight, try, attrs,...}
    ]

    disabled
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs


