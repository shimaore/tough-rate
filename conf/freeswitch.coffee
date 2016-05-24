{renderable} = L = require 'acoustic-line'
{hostname} = require 'os'

module.exports = renderable (cfg) ->
  {doctype,document,section,configuration,settings,param,modules,module,load,network_lists,list,node,global_settings,profiles,profile,mappings,map,context,extension,condition,action} = L

  # cfg.name (string) Internal name for the FreeSwitch instance
  name = cfg.name ? 'server'

  the_profiles = cfg.profiles

  modules_to_load = [
    'mod_logfile'
    'mod_event_socket'
    'mod_commands'
    'mod_dptools'
    'mod_loopback'
    'mod_dialplan_xml'
    'mod_sofia'
  ]
  if cfg.modules?
    modules_to_load = modules_to_load.concat cfg.modules

  doctype()
  document type:'freeswitch/xml', ->
    section name:'configuration', ->
      configuration name:'switch.conf', ->
        settings ->
          # cfg.host (hostname) used preferentially to the automatically-determined hostname for FreeSwitch
          param name:'switchname', value:"freeswitch-#{name}@#{cfg.host ? hostname()}"
          param name:'core-db-name', value:"/dev/shm/freeswitch/core-#{name}.db"
          param name:'rtp-start-port', value:49152
          param name:'rtp-end-port', value:65534
          param name:'max-sessions', value:2000
          param name:'sessions-per-second', value:2000
          param name:'min-idle-cpu', value:1
          param name:'loglevel', value:'err'
      configuration name:'modules.conf', ->
        modules ->
          for module in modules_to_load
            load {module}
      configuration name:'logfile.conf', ->
        settings ->
          param name:'rotate-on-hup', value:true
        profiles ->
          profile name:'default', ->
            settings ->
              param name:'logfile', value:"log/freeswitch.log"
              param name:'rollover', value:10*1000*1000
              param name:'uuid', value:true
            mappings ->
              map name:'important', value:'err,crit,alert'
      configuration name:'event_socket.conf', ->
        settings ->
          param name:'nat-map', value:false
          param name:'listen-ip', value:'127.0.0.1'
          # Inbound-Socket port
          # cfg.socket_port (integer) Port for the event socket for FreeSwitch (defaults to 5702)
          socket_port = cfg.socket_port ? 5702
          param name:'listen-port', value: socket_port
          param name:'password', value:'ClueCon'
      configuration name:"acl.conf", ->
        network_lists ->
          # cfg.acls (object) Maps ACL names to cfg.acls[].cidrs arrays for FreeSwitch.
          for name, cidrs of cfg.acls
            list name:name, default:'deny', ->
              for cidr in cidrs
                node type:'allow', cidr:cidr

      configuration name:'sofia.conf', ->
        global_settings ->
          param name:'log-level', value:1
          param name:'debug-presence', value:0
        profiles ->
          # cfg.profile_module (Node.js module) module to use to build Sofia profiles (default: tough-rate's)
          profile_module = cfg.profile_module ? require './profile'
          for name, p of the_profiles
            # cfg.profiles[].timer_t1 (integer) SIP timer T1 for FreeSwitch (default: 250)
            # cfg.profiles[].timer_t1x64 (integer) SIP timer T1*64 for FreeSwitch (default: 64*timer_t1)
            # cfg.profiles[].timer_t2 (integer) SIP timer T2 for FreeSwitch (default: 4000)
            # cfg.profiles[].timer_t4 (integer) SIP timer T4 for FreeSwitch (default: 5000)
            # Timer values see http://tools.ietf.org/html/rfc3261#page-265
            p.timer_t1 ?= 250  # 500ms in RFC3261; works well in practice
            p.timer_t4 ?= 5000 # RFC3261 section 17.1.2.2
            p.timer_t2 ?= 4000 # RFC3261 section 17.1.2.2
            p.timer_t1x64 ?= 64*p.timer_t1
            # cfg.profiles[].local_ip (string) local binding IP for SIP for FreeSwitch. Defaults to `auto`.
            p.local_ip ?= 'auto'
            # cfg.profiles[].inbound_codec (string) inbound codec list (default: `PCMA`)
            # cfg.profiles[].outbound_codec (string) outbound codec list (default: `PCMA`)
            # cfg.profiles[].acl (string) SIP port ACL name. Default: `default`
            p.inbound_codec ?= 'PCMA'
            p.outbound_codec ?= 'PCMA'
            p.acl ?= 'default'
            p.sip_trace ?= false

            p.name = name
            p.context ?= name
            p.sip_trace = true if cfg.test
            profile_module.call L, p

    section name:'dialplan', ->

      for name, p of the_profiles
        context name:name, ->
          extension name:"socket", ->
            condition field:'destination_number', expression:'^.+$', ->
              action application:'multiset', data:"profile=#{name} socket_resume=false"
              action application:'socket', data:"127.0.0.1:#{p.socket_port} async full"
              action application:'respond', data:'500 socket failure'

      return unless cfg.test

      context name:'answer', ->
        extension name:'answer', ->
          condition field:'destination_number', expression:'^\\d+$', ->
            action application:'answer'
            action application:'sleep', data:1000
