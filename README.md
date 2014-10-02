Architecture
============

- some server-management piece (daemon, forever, etc.)
- clusterized, respawn children
- web interface for management, notifications, stats
- CDRs
- gateway management; alerting
...


Controlling Records
===================

Gateway Attributes
------------------

The following parameters are common to all gateways, they might be inserted by carrier records, gateways definitions, rulesets, destination, individual rules, or individual item in a `gwlist`.
They are all optional.

    disabled          (default false)
    response_timeout  (default 2)  from invite to first response - dead-gateway timeout
    progress_timeout  (default 4)  from invite to progress (180, 183, ...) - maximum post-dial-delay
    answer_timeout    (default 90) from progress to answer (200) - maximum ringback time
    dialog_timeout    (default 28800) from answer to end - maximum call duration
    attrs             (default {})

The following attributes are applied to gateways, but generally not defined at the gateway level:

    priority          (default: 0 for the last gateway in a list, 1 for the previous one, etc.)
    local_gateway_extra_priority (default 0.5)  added to priority if the gateway is on the same host
    weight            (default 1, must be > 0)
    gwlist            (default [])

Different attribute values might be present. They are always resolved in the following order: default, carrier, gateway, ruleset, destination, rule, gwlist entry.

For all attributes except `attrs`, the most specific value is selected.

For `attrs`, each top value is either:
- OR'ed (for booleans).
- concatenated (for strings and lists); the most specific value is listed last.
- merged (for objects); for conflicting fields inside an object, the most specific value is selected.
Values of inconsistent datatypes are ignored.


gateway (individual gateway records)
------------------------------------

    _id: "gateway:#{sip_domain_name}:#{gwid}"
    type: 'gateway'

    sip_domain_name
    gwid
    address           (required) "#{ip}:#{host}", DNS name
    carrierid         (optional)

    disabled
    response_timeout
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs

Differences with ccnq3:
- Some optional fields (`probe_mode`,`strip`,`pri_prefix`,`attrs`) are no longer supported.
- New fields have been introduced.


gateway (as part of host)
-------------------------

Gateways are defined inside `sip_profiles`; the following fields are available inside a given `sip_profiles` entry:

    egress.gwid
    egress.carrierid

    egress.disabled
    egress.response_timeout
    egress.progress_timeout
    egress.answer_timeout
    egress.dialog_timeout
    egress.attrs

The following gateway fields do not need to be specified:
- `address` is computed based on the profile's data;
- `sip_domain_name` is taken from the host.

Differences with ccnq3:
- The ccnq3 field `egress_gwid` has been obsoleted; it will be mapped to `egress.gwid` if the later is not present.


carrier
-------

A carrier offers one or more gateways.

A carrier is indicated alongside a gateway definition, either inside a `gateway` record, or in the `sip_profiles` part of a host definition.

A carrier record might optionally be created to provide carrier-wide default values for the gateways listed under that carrier.

    _id: "carrier:#{sip_domain_name}:#{carrierid}"
    type: 'carrier'

    sip_domain_name
    carrierid
    try (default 1, must be > 0)

    local_gateway_extra_priority
    disabled
    response_timeout
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs

Differences with ccnq3:
- Carriers are defined inside a `sip_domain_name`, not inside a host. The field `local_gateway_extra_priority` is used instead in order to prioritize gateways local to a host.
- The `gwlist` field found in the carrier records has been replaced by indication on each gateway. (This means a gateway can only belong to a single carrier. Conversely it prevents issues where inexistent gateways might be listed in a carrier.)


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

destination
-----------

A destination record might be referenced by a rule in order to provide defaults for that rule.

    _id: "destination:#{destination}"
    type: 'destination'
    destination: destination

    disabled
    response_timeout
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs

rule
----

Rules are defined in a ruleset database. There is one ruleset database per ruleset.

    _id: "rule:#{prefix}"
    type: 'rule'
    destination (optional)
    gwlist: [
      {gwid, attrs,response_timeout,...}
      {carrierid,try, attrs,response_timeout,...}
    ]

    disabled
    response_timeout
    progress_timeout
    answer_timeout
    dialog_timeout
    attrs


The gwlist is converted into a list of gateways as follows:
- Each record in the list is assigned an additional priority, starting from 0 for the last item in the list and adding 1 going backwards in the list.
- Records which have a `carrierid` and no `gwid` are replaced with a list of the gateways for that carrierid, up to `try` entries. The value of `try` defaults to the number of gateways for that carrier. Gateways are selected using weighted round-robin.
- Records which have a `gwid` are gateways. Other records are rejected.
- Any gateway local to the host receives an additional `local_gateway_priority` (by default 0.5).
- In the resulting list, gateways are sorted by descending priority. Gateways with identical priorities are sorted using weighted round-robin.

Differences with ccnq3:
- Since the `sip_domain_name` and `groupid` are common to all the rules inside a ruleset, they are not repeated inside the individual `rule` records.
