Live test with FreeSwitch
=========================

    chai = require 'chai'
    chai.use require 'chai-as-promised'
    should = chai.should()

    Promise = require 'bluebird'
    real_exec = Promise.promisify (require 'child_process').exec
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:test:call_server"
    CaringBand = require 'caring-band'
    fs = Promise.promisifyAll require 'fs'

    seem = require 'seem'

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

Setup
=====

    ready = seem ->
      debug 'ready'
      yield fs
        .mkdirAsync 'test/live'
        .catch (error) ->
          debug "mkdir #{error.stack ? error} (ignored)"
      cfg =
        test: yes
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
          default: [ '127.0.0.0/8' ]
      xml = (require 'huge-play/conf/freeswitch') cfg
      yield fs
        .writeFileAsync 'test/live/freeswitch.xml', xml, 'utf-8'
        .catch (error) -> debug "write: #{error} in #{process.cwd()} (ignored)"
      yield exec("docker kill #{p}").catch -> true
      yield exec("docker rm #{p}").catch -> true
      yield exec """
        docker run --net=host -d --name #{p} -v "#{pwd}/test/live:/opt/freeswitch/etc/freeswitch" shimaore/docker.freeswitch /opt/freeswitch/bin/freeswitch -nf -nosql -nonat -nonatmap -nocal -nort -c
      """
      debug 'Docker with FreeSwitch should be running, starting our own server.'
      server = yield start_server()
      debug 'Start server OK, waiting...'
      yield Promise.delay 10000
      debug 'Start server OK, done.'
      null

Server (Unit Under Test)
========================

    PouchDB = require 'pouchdb-core'
      .plugin require 'pouchdb-adapter-memory'
      .defaults adapter: 'memory'
    FS = require 'esl'
    options = null

    start_server = seem ->
      debug 'start_server'
      provisioning = null
      sip_domain_name = 'phone.local'
      yield new PouchDB('live-provisioning').destroy().catch -> true
      yield new PouchDB('the_default_live_ruleset').destroy().catch -> true
      provisioning = new PouchDB 'live-provisioning'
      yield provisioning.bulkDocs [
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
      ruleset = new PouchDB 'the_default_live_ruleset'
      yield ruleset.bulkDocs [
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
      yield provisioning.put GatewayManager.couch

      ruleset_of = (x) ->
        provisioning.get "ruleset:#{sip_domain_name}:#{x}"
        .then (doc) ->
          ruleset: doc
          ruleset_database: new PouchDB doc.database

      options =
        prov: provisioning
        profile: 'huge-play-test-sender-egress'
        host: 'example.net'
        ruleset_of: ruleset_of
        sip_domain_name: sip_domain_name
        statistics: new CaringBand()
        prefix_admin: ''
        use: [
          'tangible/middleware'
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
      catcher.listen 7004

      debug 'Declaring Server'
      ctx = cfg: options
      for m in options.use
        yield m.server_pre?.call ctx
      CallServer = require 'useful-wind/call_server'
      s = new CallServer options
      s.listen 7002
      debug 'start_server done'
      s

Test
====

    test1 = ->
      new Promise (resolve,reject) ->
        setTimeout ->
          reject new Error 'test1 timed out'
        , 6000
        try
          client = FS.client ->
            source = '1234'
            destination = '33142'
            debug 'test1: originate'
            @api "originate {origination_caller_id_number=#{source}}sofia/huge-play-test-sender-ingress/sip:#{destination}@#{domain} &park"
            .then ->
              debug 'test1: delay'
              Promise.delay 700
            .then ->
              debug 'test1: client.end'
              client.end()
              resolve true
            .catch (exception) ->
              debug "test1 Error: #{exception}"
              client.end()
              reject exception
          client.on 'error', (data) ->
            debug 'test1.on error', data
            client.end()
            reject new Error "test1 error #{data}"
          debug 'test1 client.connect'
          client.connect 5722, '127.0.0.1'
          debug 'test1 connecting'
          client
        catch exception
          debug 'test1 caught', exception
          reject exception

    test2 = ->
      new Promise (resolve,reject) ->
        setTimeout ->
          reject new Error 'test2 timed out'
        , 6000
        try
          client = FS.client ->
            source = '1235'
            destination = '33_112'
            debug 'test2: originate'
            @api "originate [origination_caller_id_number=#{source},sip_h_X-Bear=home]sofia/huge-play-test-sender-ingress/sip:#{destination}@#{domain} &park"
            .then ->
              debug 'test2: client.end()'
              client.end()
              resolve true
            .catch (exception) ->
              debug 'test2: exception'
              client.end()
              reject exception
          client.on 'error', (data) ->
            debug 'test2.on error', data
            client.end()
            reject new Error "test2 error: #{data}"
          debug 'test2 connect'
          client.connect 5722, '127.0.0.1'
          debug 'test2 connecting'
          client
        catch exception
          debug 'test2 caught', exception
          reject exception

    describe 'Live Tests', ->

      describe 'FreeSwitch', ->
        @timeout 21000
        before ->
          @timeout 40000
          ready()
        it 'should process a regular call', ->
          t = test1()
          t.should.be.fulfilled
          t.should.eventually.equal true
        it 'should process a registrant call', ->
          t = test2()
          t.should.be.fulfilled
          t.should.eventually.equal true

      after seem ->
        @timeout 20000
        debug "Stopping..."
        server?.stop()
        debug "Server stopped, now stopping docker instance..."
        yield exec "docker logs #{p} > #{p}.log"
        yield exec "docker kill #{p}"
        yield exec "docker rm #{p}"
