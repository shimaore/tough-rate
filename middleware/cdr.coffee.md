    module.exports = ->
      cdr_base = @options.cdr_base

      middleware = ->

        @call.trace true
        @call.once 'CHANNEL_HANGUP_COMPLETE'
        .then (res) =>
          data = res.body

          @logger.info "CDR: Channel Hangup Complete", billmsec: data.variable_billmsec
          @statistics.add 'duration', data.variable_mduration
          @statistics.add 'billable', data.variable_billmsec
          @statistics.add 'progresss', data.variable_progressmsec
          @statistics.add 'answer', data.variable_answermsec
          @statistics.add 'wait', data.variable_waitmsec
          @statistics.add 'progress_media', data.variable_progress_mediamsec
          @statistics.add 'flow_bill', data.variable_flow_billmsec

variable_mduration: # total duration
variable_billmsec: # billable (connected)
variable_progressmsec: # progress
variable_answermsec: # answer
variable_waitmsec: # wait = answer?
variable_progress_mediamsec: # 0
variable_flow_billmsec: # total duration
