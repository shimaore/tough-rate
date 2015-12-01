{renderable} = L = require 'acoustic-line'

module.exports = renderable (cfg) ->
  {doctype,document,section,configuration,settings,param,modules,module,load,network_lists,list,node,global_settings,profiles,profile,mappings,map,context,extension,condition,action} = L
  name = cfg.name ? 'server'
  the_profiles = cfg.profiles ?
    sender:
      sip_port: 5060
      socket_port: 5701 # Outbound-Socket port
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
          param name:'switchname', value:"freeswitch-#{name}"
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
          socket_port = cfg.socket_port ? 5702
          param name:'listen-port', value: socket_port
          param name:'password', value:'ClueCon'
      configuration name:"acl.conf", ->
        network_lists ->
          for name, cidrs of cfg.acls
            list name:name, default:'deny', ->
              for cidr in cidrs
                node type:'allow', cidr:cidr

      configuration name:'sofia.conf', ->
        global_settings ->
          param name:'log-level', value:1
          param name:'debug-presence', value:0
        profiles ->
          profile_module = cfg.profile_module ? require './profile'
          for name, p of the_profiles
            p.timer_t1 ?= 250
            p.timer_t4 ?= 5000
            p.timer_t2 ?= 4000
            p.timer_t1x64 ?= 64*p.timer_t1
            p.local_ip = 'auto'
            p.name = name
            p.context ?= "context-#{name}"
            profile_module.call L, p

    section name:'dialplan', ->

      for name, p of the_profiles
        context name:"context-#{name}", ->
          extension name:"socket", ->
            condition field:'destination_number', expression:'^.+$', ->
              action application:'socket', data:"127.0.0.1:#{p.socket_port} async full"
