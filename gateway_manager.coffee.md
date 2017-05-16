Gateway (and carriers) manager
==============================

    seem = require 'seem'

The gateway manager provides services to the call handler.

    default_parameters =
      disabled: false
      progress_timeout: 12
      answer_timeout: 90
      dialog_timeout: 28800
      attrs: {}
      local_gateway_first: true
      weight: 1
      try: 1

    module.exports = class GatewayManager

      constructor: (@provisioning,@sip_domain_name) ->
        @carriers = {}
        @gateways = {}
        @gateway_status = {}
        assert @provisioning, "GatewayManager: provisioning DB is required"
        assert @sip_domain_name, "GatewayManager: sip_domain_name is required"
        @default_parameters = {}
        for own k,v of default_parameters
          @default_parameters[k] ?= v
        debug "GatewayManager #{pkg.name} #{pkg.version} for #{@sip_domain_name}: waiting for init()"

`set` accepts either `set(name,value)` or `set({name:value,name2:value,...})`.

      set: (name,value) ->
        if typeof name is 'string'
          @default_parameters[name] = value
        else
          for own k,v of name
            @default_parameters[k] = v

* doc.carrier Parameters of an egress carrier.
* doc.carrier._id (string,required) `carrier:<sip_domain_name>:<carrierid>`
* doc.carrier.type (string,required) `carrier`
* doc.carrier.carrier (string, required) `<sip_domain_name>:<carrierid>`
* doc.carrier.sip_domain_name (string, required)
* doc.carrier.carrierid (string, required)

      init: seem ->

        {rows} = yield @provisioning
          .allDocs startkey:"carrier:#{@sip_domain_name}:", endkey:"carrier:#{@sip_domain_name};", include_docs:yes

        if rows?
          for row in rows when row.doc?
            yield @_merge_carrier row.doc

        {rows} = yield @provisioning
          .query "#{design}/gateways", startkey:[@sip_domain_name], endkey:[@sip_domain_name,{}]

        if rows?
          for row in rows when row.value?
            do (row) => @_merge_gateway row.value

        debug 'GatewayManager init completed', {@sip_domain_name,@gateways,@carriers}
        return

        # TODO Add monitoring of `_changes` on the view to update carriers and gateways

* doc.gateway Parameters for an outbound gateway
* doc.gateway.gwid (string,required)
* doc.gateway.carrierid (string) Carrier for this gateway (see doc.carrier )
* doc.gateway.disabled (boolean) optional field to mark the gateway as inexistent

      _merge_gateway: (value) ->
        debug 'GatewayManager merge-gateway', {value}

        {address,gwid,carrierid} = value
        unless address?
          debug 'Missing address, ignoring', value
          return

        unless gwid?
          debug 'Missing gwid, ignoring', value
          return

        if value.disabled
          if carrierid?
            delete @carriers[carrierid]?._gateways[gwid]
          delete @gateways[gwid]
          return

        if carrierid?
          @gateways[gwid] = field_merger [
            @default_parameters
            @carriers[carrierid]
            value
          ]

          @carriers[carrierid] ?= _gateways: {}
          @carriers[carrierid]._gateways[gwid] = true
        else
          @gateways[gwid] = field_merger [
            @default_parameters
            value
          ]
          for k,v of @carriers
            delete v._gateways?[gwid]

        return

      _reevaluate_gateways: seem (gateway_names) ->
        debug 'GatewayManager reevaluate gateways', gateway_names
        {rows} = yield @provisioning
          .query "#{design}/gateways", keys:gateway_names.map (x) => [@sip_domain_name,x]

        for row in rows when row.value?
          do (row) => @_merge_gateway row.value

* doc.carrier.carrierid (string,required) identifier for the carrier, used in doc.carrier._id
* doc.carrier.disabled (boolean) optional field to mark the carrier as non-existent

      _merge_carrier: seem (value) ->
        debug 'GatewyManager merge-carrier', value

        carrierid = value.carrierid
        unless carrierid?
          debug 'Missing carrierid, ignoring', value
          return

        if value.disabled
          gateway_names = Object.getOwnPropertyNames @carriers[carrierid]._gateways
          delete @carriers[carrierid]
          yield @_reevaluate_gateways gateway_names
          return

        @carriers[carrierid] ?= _gateways: {}
        for own k,v of value
          @carriers[carrierid][k] = v

        return

      _retrieve_gateway: seem (name) ->
        # TODO update with dynamic parameters (temporarily_disabled, ...)
        return null unless name of @gateways
        info = {}
        info[k] = v for own k,v of @gateways[name]
        info.temporarily_disabled = @gateway_status[name]?.state in ['faulty']
        yield info

      _retrieve_carrier: seem (name) ->
        yield @carriers[name]


Gateway and carrier properties mapping
--------------------------------------

Return gateway data (inside a list) as long as that gateway is available.

      resolve_gateway: seem (name) ->
        info = yield @_retrieve_gateway name
        if not info?
          return []
        if info.disabled or info.temporarily_disabled
          return []
        [info]

Return gateway data (inside a list) for a given carrier.

      resolve_carrier:  seem (name) ->
        carrier = {}
        carrier = yield @_retrieve_carrier name
        if not carrier?
          return []
        if not carrier._gateways?
          return []

        res = []
        for own gw of carrier._gateways
          [x] = yield @resolve_gateway gw
          res.push x

        res

Gateway ping
------------

Pings a gateway to confirm it is still alive.

Gateway temporary disable
-------------------------

Disable a gateway temporarily, for example because it is rejecting too many calls.

      mark_gateway_as_faulty: (name) ->
        assert name?, 'GatewayManager mark-gateway-as-faulty: name is required'
        debug "GatewayManager mark-gateway-as-faulty: #{name}."
        status = @gateway_status[name] ?= new Status()
        status.mark_as_faulty()

Mark a gateway as suspicious.

      mark_gateway_as_suspicious: (name) ->
        assert name?, 'GatewayManager mark-gateway-as-suspicious: name is required'
        debug "GatewayManager mark-gateway-as-suspicious: #{name}."
        status = @gateway_status[name] ?= new Status()
        status.mark_as_suspicious()


Carrier temporary disable
-------------------------

Disable a carrier temporarily, for example because it is rejecting too many calls.

Provisioning monitoring
-----------------------

Monitors `_changes` on the provisioning views to automatically update the internal status of gateways, carriers, etc.

Toolbox
=======

    pkg = require './package.json'
    design = "#{pkg.name}-gateway-manager"
    {p_fun} = require 'coffeescript-helpers'

    GatewayManager.couch =
      _id: "_design/#{design}"
      language: "javascript"

For an individual gateway we expect the following fields must be present in the view:

- `sip_domain_name`
- `gwid`
- `address`

The following fields are optional:

- `carrierid`
- `disabled`
- `progress_timeout`
- `answer_timeout`
- `dialog_timeout`
- `attrs`


      views:
        gateways:
          map: p_fun (doc) ->
            return unless doc.type?

* doc.gateway.sip_domain_name (string, required) SIP domain name
* doc.gateway.gwid (string, required) Gateway identifier in the doc.gateway.sip_domain_name
* doc.gateway.address (string, required) SIP URI domain to be used to route calls to that gateway
* doc.gateway.carrierid (string, optional) Carrier route this gateway belongs to.

            if doc.type is 'gateway'
              return emit [doc.sip_domain_name, doc.carrierid], doc

* doc.host.sip_profiles[] (object) FreeSwitch SIP profiles. Required in the database to build DNS records and route entries.
* doc.host.sip_profiles[].egress_sip_ip (string) IP address for egress calls. Default: doc.host.sip_profiles[].ingress_sip_ip
* doc.host.sip_profiles[].ingress_sip_ip (string) IP address for ingress calls.
* doc.host.sip_profiles[].egress_sip_port (integer) SIP port for egress calls. Default: doc.host.sip_profiles[].ingress_sip_port + 1000
* doc.host.sip_profiles[].ingress_sip_port (integer) SIP port for ingress calls

            if doc.type is 'host' and doc.sip_profiles?
              for name, rec of doc.sip_profiles
                do (rec) ->
                  # for now we only generate for egress gateways
                  ip = rec.egress_sip_ip ? rec.ingress_sip_ip
                  port = rec.egress_sip_port ? rec.ingress_sip_port+10000

* doc.host.sip_profiles[].egress (object) Description of the SIP profile as a gateway. This allows the SIP profile to be used directly, without the need for a doc.gateway document.
* doc.host.sip_profiles[].egress.gwid (string) Gateway identifier for this profile.
* doc.host.sip_profiles[].egress_gwid (string, obsolete) Gateway identifier for this profile. Used if doc.host.sip_profiles[].egress.gwid is not defined. (CCNQ3 convention.)
* doc.host.sip_profiles[].egress.address (string) Destination for egress calls. Default: doc.host.sip_profiles[].egress_sip_ip and doc.host.sip_profiles[].egress_sip_port
* doc.host.sip_profiles[].egress.host (string) Host for this profile. Default: doc.host.host
* doc.host.sip_profiles[].egress.carrier (string) Carrier for this profile. Used for call rating. Default: the `gwid` value.
* doc.host.sip_profiles[].egress.name (string) Display name for this profile.
* doc.host.sip_profiles[].egress.disabled (boolean) If true the gateway is ignored
* doc.host.host (string) Hostname. Used to build doc.host._id
* doc.host.sip_domain_name (string) SIP domain name for the host.
* doc.host.sip_profiles[].egress.carrierid (string) Carrier identifier for this profile (considered as a gateway).

                  egress = {}
                  egress[k] = v for own k,v of rec.egress
                  egress.gwid ?= rec.egress_gwid
                  egress.address ?= [ip,port].join ':'
                  egress.host ?= doc.host
                  egress.disabled ?= doc.disabled
                  if egress.gwid?
                    emit [doc.sip_domain_name, egress.carrierid], egress
                  return

            return

    field_merger = require './field_merger'
    assert = require 'assert'
    Status = require './status'
    debug = (require 'tangible') "#{pkg.name}:gateway_manager"
