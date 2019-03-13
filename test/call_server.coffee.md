Live test with FreeSwitch
=========================

    chai = require 'chai'
    chai.should()

    {promisify} = require 'util'
    real_exec = promisify (require 'child_process').exec
    {spawn} = require 'child_process'
    to_stream = require 'into-stream'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:test:call_server"
    CaringBand = require 'caring-band'
    os = require 'os'

    sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout

Parameters for docker.io image
==============================

    pwd = process.cwd()

    IMG = "#{pkg.name}-test"
    t = 'live'
    p = "#{IMG}-#{t}"
    DNS = null
    domain_name = '127.0.0.1'
    domain = "#{domain_name}:5062"
    exec = (cmd) ->
      debug cmd
      real_exec cmd

    server = null
    catcher = null

    db_base = "http://#{process.env.COUCHDB_USER}:#{process.env.COUCHDB_PASSWORD}@couchdb:5984/"

Setup
=====

    address = null
    for intf,mappings of os.networkInterfaces() when not intf.match /^(docker|veth)/
      for val in mappings when val.family is 'IPv4' and not val.internal
        address ?= val.address

    debug 'Selected IP', address

    ready = ->
      debug 'ready'
      cfg =
        test: yes
        socket_ip: address
        profiles:
          'test-sender':
            sip_port: 5062
            local_ip: '127.0.0.1'
            socket_port: 7002 # Outbound-Socket port
          'test-catcher':
            sip_port: 5064
            local_ip: '127.0.0.1'
            socket_port: 7004 # Outbound-Socket port
        acls:
          default: [ '0.0.0.0/0' ]
        socket_ip: '0.0.0.0'
        socket_acl: 'default'
      xml = (require 'huge-play/conf/freeswitch') cfg

      console.log "docker kill"
      {stdout,stderr} = await exec("docker kill #{p}").catch ({stdout,stderr}) -> {stdout,stderr}
      console.log stdout
      console.error stderr

      console.log "docker rm"
      {stdout,stderr} = await exec("docker rm #{p}").catch ({stdout,stderr}) -> {stdout,stderr}
      console.log stdout
      console.error stderr

      console.log "docker run"
      child = spawn 'docker', ['run', '-i', '-p', '5722:5722', '--name', p, 'gitlab.k-net.fr:1234/ccnq/docker.freeswitch:4.4.0', 'bash', '-c',
        'tee /opt/freeswitch/etc/freeswitch/freeswitch.xml && /opt/freeswitch/bin/freeswitch -nf -nosql -nonat -nonatmap -nocal -nort -c'],
        # stdio: ['pipe',process.stdout,process.stderr]
        stdio: ['pipe','ignore','ignore']
      child.on 'close', (code,signal) ->
        debug 'FreeSwitch ended', code, signal
      ###
      xml = xml.replace '<param name="loglevel" value="err"/>',
                        '<param name="loglevel" value="debug"/>'
      ###

      xml = xml.replace /socket:127\.0\.0\.1:(\d+) async full/g,
                        "socket:#{address}:$1 async full"

      child.stdin.end xml, 'utf-8'

      console.log "docker ps"
      {stdout,stderr} = await exec "docker ps"
      console.log stdout
      console.error stderr

      await sleep 20000

      console.log "docker ps"
      {stdout,stderr} = await exec "docker ps"
      console.log stdout
      console.error stderr


      debug 'Docker with FreeSwitch should be running, starting our own server.'
      server = await start_server()
      debug 'Start server OK, waiting...'
      await sleep 10000

      console.log "docker ps"
      {stdout,stderr} = await exec "docker ps"
      console.log stdout
      console.error stderr
      debug 'Start server OK, done.'

      null

Server (Unit Under Test)
========================

    CouchDB = require './most-couchdb'
    FS = require 'esl'
    options = null

    start_server = ->
      debug 'start_server'
      provisioning = null
      sip_domain_name = 'phone.local'
      provisioning = new CouchDB db_base+'live-provisioning'
      ruleset = new CouchDB db_base+'the_default_live_ruleset'
      await provisioning.destroy().catch -> true
      await ruleset.destroy().catch -> true
      await provisioning.create()
      await provisioning.bulkDocs [
        {
          _id:'gateway:phone.local:gw1'
          type:'gateway'
          sip_domain_name:'phone.local'
          gwid:'gw1'
          address:"#{domain_name}:5064"
          codecs:"PCMA,PCMU"
        }
        {
          _id:'ruleset:phone.local:default'
          type:'ruleset'
          sip_domain_name:'phone.local'
          groupid:'default'
          database:'the_default_live_ruleset'
        }
        {
          _id:'emergency:33_112#brest'
          destination:'33156'
        }
        {
          _id:'location:home'
          routing_data:'brest'
        }
        {
          _id:'number:1234'
          outbound_route:'default'
        }
        {
          _id:'number:1235'
          outbound_route:'default'
          registrant_host: "#{domain_name}:5064"
        }
      ]
      await ruleset.create()
      await ruleset.bulkDocs [
        {
          _id:'prefix:331'
          gwlist: [
            {gwid:'gw1'}
          ]
          attrs:
            cdr: 'foo-bar'
        }
        {
          _id:'prefix:33_112'
          emergency:true
        }
      ]
      debug 'Inserting Gateway Manager Couch'
      GatewayManager = require '../gateway_manager'
      await provisioning.put GatewayManager.couch

      ruleset_of = (x) ->
        provisioning.get "ruleset:#{sip_domain_name}:#{x}"
        .then (doc) ->
          ruleset: doc
          ruleset_database: new CouchDB db_base + doc.database, true

      options =
        provisioning: db_base+'live-provisioning'
        profile: 'huge-play-test-sender-egress'
        host: 'example.net'
        ruleset_of: ruleset_of
        sip_domain_name: sip_domain_name
        prefix_admin: ''
        redis: host: 'redis'
        blue_rings:
          host: 'a'
        use: [
          'huge-play/middleware/setup'
          './catcher'
          './standalone'
          '../middleware/setup'
          '../middleware/numeric'
          '../middleware/response-handlers'
          '../middleware/local-number'
          '../middleware/ruleset'
          '../middleware/emergency'
          '../middleware/routes-gwid'
          '../middleware/routes-carrierid'
          '../middleware/routes-registrant'
          '../middleware/flatten'
          '../middleware/cdr'
          '../middleware/call-handler'
          '../middleware/use-ccnq-to-e164'
        ].map (m) ->
          require m

      debug 'Declaring Catcher'
      catcher = (require 'esl').server ->
        @command 'answer'
      catcher.listen 7004, address

      debug 'Declaring Server'
      ctx = cfg: options
      for m in options.use
        await m.server_pre?.call ctx
      CallServer = require 'useful-wind/call_server'
      s = new CallServer options
      s.listen 7002, address
      debug 'start_server done'
      s

Test
====

    describe 'Live Tests', ->

      @timeout 21000
      before ->
        @timeout 60000
        await ready()

      describe 'FreeSwitch', ->
        it 'should process a regular call', (done) ->
          @timeout 6000
          after ->
            client.end()
          client = FS.client ->
            source = '1234'
            destination = '33142'
            debug 'test1: originate'
            @api "originate {origination_caller_id_number=#{source}}sofia/huge-play-test-sender-ingress/sip:#{destination}@#{domain} &park"
            .then ->
              debug 'test1: delay'
              await sleep 700
            .then ->
              debug 'test1: client.end'
              client.end()
              done()
            .catch (exception) ->
              debug "test1 Error: #{exception}"
              client.end()
              done exception
          client.on 'error', (data) ->
            debug 'test1.on error', data
            client.end()
            done new Error "test1 error #{data}"
          debug 'test1 client.connect'
          client.connect 5722, '127.0.0.1'
          debug 'test1 connecting'

      it 'should process a registrant call', (done) ->
          @timeout 6000
          after ->
            client.end()
          client = FS.client ->
            source = '1235'
            destination = '33_112'
            debug 'test2: originate'
            @api "originate [origination_caller_id_number=#{source},sip_h_X-Bear=home]sofia/huge-play-test-sender-ingress/sip:#{destination}@#{domain} &park"
            .then ->
              debug 'test2: client.end()'
              client.end()
              done()
            .catch (exception) ->
              debug 'test2: exception'
              client.end()
              done exception
          client.on 'error', (data) ->
            debug 'test2.on error', data
            client.end()
            done new Error "test2 error: #{data}"
          debug 'test2 connect'
          client.connect 5722, '127.0.0.1'
          debug 'test2 connecting'

      after ->
        @timeout 20000
        debug "Stopping..."
        server?.stop()
        catcher?.close()
        debug "Server stopped, now stopping docker instance..."
        await exec "docker kill #{p}"
        await exec "docker rm #{p}"
