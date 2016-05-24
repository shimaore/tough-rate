{renderable} = require 'acoustic-line'
pkg = require '../package'

module.exports = renderable (o) ->
  {profile,settings,param} = this
  profile name:"#{pkg.name}-#{o.name}", ->
    settings ->
      param name:'user-agent-string', value:"#{pkg.name}-#{o.name}-#{o.sip_port}"
      param name:'username', value:"#{pkg.name}-#{o.name}"
      param name:'debug', value:2
      param name:'sip-trace', value:o.sip_trace

      # SIP
      param name:'sip-ip', value:o.local_ip
      param name:'ext-sip-ip', value:o.local_ip
      param name:'sip-port', value:o.sip_port
      param name:'bind-params', value:'transport=udp' # tcp

      param name:'apply-inbound-acl', value:o.acl
      param name:'disable-transfer', value:o.disable_transfer
      param name:'enable-3pcc', value:false

      param name:'inbound-use-callid-as-uuid', value:true
      param name:'outbound-use-uuid-as-callid', value:false

      param name:'dialplan', value:"inline:'socket:127.0.0.1:#{o.socket_port} async full'"
      param name:'context', value:o.context
      param name:'max-proceeding', value:3000

      param name:'forward-unsolicited-mwi-notify', value: false
      param name:'sip-options-respond-503-on-busy', value:false

      param name:'timer-T1', value:o.timer_t1
      param name:'timer-T1X64', value:o.timer_t1x64
      param name:'timer-T2', value:o.timer_t2
      param name:'timer-T4', value:o.timer_t4

      # Auth
      param name:'log-auth-failures', value:true
      param name:'accept-blind-auth', value:true
      param name:'auth-calls', value:false
      param name:'auth-all-packets', value:false
      param name:'nonce-ttl', value:60

      # CID
      param name:'pass-callee-id', value:false
      param name:'caller-id-type', value:'pid'

      # Presence
      param name:'manage-presence', value:false
      param name:'manage-shared-appearance', value:false

      # Registration
      param name:'disable-register', value:true
      param name:'accept-blind-reg', value:false
      param name:'NDLB-received-in-nat-reg-contact', value:false
      param name:'all-reg-options-ping', value:false
      param name:'nat-options-ping', value:false

      # RTP
      param name:'rtp-ip', value:o.local_ip
      param name:'ext-rtp-ip', value:o.local_ip

      param name:'rtp-timeout-sec', value:300
      param name:'rtp-hold-timeout-sec', value:1800

      if true
          param name:'enable-soa', value:false
          param name:'inbound-bypass-media', value:true
          # Enter the dialplan without the codec having been negotiated.
          param name:'inbound-late-negotiation', value:true

      # Only enable proxy-media on a call-by-call-basis
      param name:'inbound-proxy-media', value:false

      param name:'media-option', value:'none'

      param name:'inbound-zrtp-passthru', value:false
      # disable-transcoding doesn't actuall disable the transcoding facility;
      # "This parameter just changes the outbound codec to match the one negotiated on the inbound leg so that no transcoding will be required."
      param name:'disable-transcoding', value:true

      param name:'use-rtp-timer', value:true
      param name:'rtp-timer-name', value:'soft'

      # Codec
      param name:'inbound-codec-prefs', value:o.inbound_codec
      param name:'outbound-codec-prefs', value:o.outbound_codec
      param name:'inbound-codec-negotiation', value:'scrooge'
      param name:'renegotiate-codec-on-reinvite', value:true

      # DTMF
      param name:'dtmf-type', value:'rfc2833'
      param name:'rfc2833-pt', value:101
      param name:'dtmf-duration', value:200
      param name:'pass-rfc2833', value:true

      # NAT
      if true
          param name:'aggressive-nat-detection', value:false
      param name:'stun-enabled', value:false
      param name:'stun-auto-disable', value:true
