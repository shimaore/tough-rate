    seem = require 'seem'

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    @include = seem ->

      return unless @session.direction is 'lcr'

Compatibility layer for CCNQ3 -- remove once the LCR generates its own CDRs.

* hdr.X-CCNQ3-Attrs JSON-encoded attributes, set in LCR so that they show up in CDRs as doc.CDR.variables.ccnq_attrs.
* doc.CDR.variables.ccnq_attrs ignore
* doc.prefix.attrs (object) Attributes copied to hdr.X-CCNQ3-Attrs as a JSON string.
* doc.destination.attrs (object) Attributes copied to hdr.X-CCNQ3-Attrs as a JSON string.

      attrs = {}
      for own k,v of @res.attrs when v?
        attrs[k] = v
      json_attrs = JSON.stringify attrs
      yield @set

Export attributes towards the carrier SBC (this is used to map carrier-side CDRs with client-side CDRs).

        'sip_h_X-CCNQ3-Attrs': json_attrs

Export attributes in our local CDR.

        ccnq_attrs: json_attrs

      null
