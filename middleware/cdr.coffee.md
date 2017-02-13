    seem = require 'seem'

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    @include = seem ->

      return unless @session.direction is 'lcr'

      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then (res) =>

Export winner data to our local CDR

        @debug "CDR: Channel Hangup Complete"
        data = res.body

        @debug "CDR: Channel Hangup Complete", billmsec: data.variable_billmsec
        data =
          duration:       data.variable_mduration
          billable:       data.variable_billmsec
          progress:       data.variable_progressmsec
          answer:         data.variable_answermsec
          wait:           data.variable_waitmsec
          progress_media: data.variable_progress_mediamsec
          flow_bill:      data.variable_flow_billmsec

        for own k,v of data
          @statistics.add k, v
          @statistics.add ["#{k}-gw",@session.gateway?.gwid], v
          @statistics.add ["#{k}-gw",@session.gateway?.gwid,@rule?.prefix], v
          @statistics.add ["#{k}-carrier",@session.gateway?.carrierid], v
          @statistics.add ["#{k}-carrier",@session.gateway?.carrierid,@rule?.prefix], v

        @statistics.emit 'call',
          state: 'end'
          call: @call.uuid
          source: @source
          destination: @destination
          data: data

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

Export attributes towards the carrier SBC

        'sip_h_X-CCNQ3-Attrs': json_attrs

Export attributes in our local CDR

        ccnq_attrs: json_attrs

      null

variable_mduration: # total duration
variable_billmsec: # billable (connected)
variable_progressmsec: # progress
variable_answermsec: # answer
variable_waitmsec: # wait = answer?
variable_progress_mediamsec: # 0
variable_flow_billmsec: # total duration
