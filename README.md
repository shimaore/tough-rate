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

gateway (individual gateway records)
------------------------------------

    _id: "gateway:#{sip_domain_name}:#{gwid}"
    type: 'gateway'

    sip_domain_name
    gwid

The following parameters are common to all gateways and might be inserted by carrier records:

    address
    carrierid
    attrs (default {})
    priority (default 0)
    weight (default 1, must be > 0)
    response_timeout (default 2)
    progress_timeout (default none)
    answer_timeout (default 90)
    dialog_timeout (default 28800)
    disabled (default false)
    local_gateway_extra_priority (default 100)

Differences with ccnq3:
- Some optional fields (`probe_mode`,`strip`,`pri_prefix`,`attrs`) are no longer supported.
- New fields have been introduced.


gateway (as part of host)
-------------------------

Gateways are defined inside `sip_profiles`; the following fields are available inside a given `sip_profiles` entry:

    egress.gwid
    egress.carrierid
    egress.attrs (default {})
    egress.priority (default 0)
    egress.weight (default 1, must be > 0)
    egress.response_timeout (default 2)
    egress.progress_timeout (default none)
    egress.answer_timeout (default 90)
    egress.dialog_timeout (default 28800)
    egress.disabled (default false)
    egress.local_gateway_extra_priority (default 100)

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

    attrs (default {})
    response_timeout (default 2)
    progress_timeout (default none)
    answer_timeout (default 90)
    dialog_timeout (default 28800)
    disabled (default false)
    local_gateway_extra_priority (default 100)

Differences with ccnq3:
- Carriers are defined inside a `sip_domain_name`, not inside a host. `local_gateway_extra_priority` is used instead in order to prioritize gateways local to a host.
- The `gwlist` field found in the carrier records has been removed and replaced by indication on each gateway. (This means a gateway can only belong to a single carrier. Conversely it prevents issues where inexistent gateways might be listed in a carrier.)


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

The title is the name shown in the management tools.
The description is a longer description of what this ruleset is about.
The database indicates the name of the database used to store the ruleset.


rule
----

Rules are defined in a ruleset database. There is one ruleset database per ruleset.

    _id: "#{prefix}"
    type: 'rule'
    attrs: {}
    gwlist: [
      {gwid, attrs,response_timeout,progress_timeout,answer_timeout,dialog_timeout}
      {carrierid,try, attrs,response_timeout,progress_timeout,answer_timeout,dialog_timeout}
    ]
    disabled (default false)

The gwlist is converted into a list of gateways as follows:
- Records which have a `gwid` are gateways.
- Records which have a `carrierid` are replaced with a list of the gateways for that carrierid, up to `try` entries. The value of `try` defaults to the number of gateways for that carrier.
- In the resulting list, gateways are sorted by descending priority; a gateway local to the server has an additional `local_gateway_priority` (by default 100). Gateways with identical priorities are served using weighted round-robin.

Differences with ccnq3:
- Since the `sip_domain_name` and `groupid` are common to all the rules inside a ruleset, they are not repeated inside the individual `rule` records.
