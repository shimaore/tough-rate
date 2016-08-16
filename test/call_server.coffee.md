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

    ready = Promise.resolve()
    .then ->
      fs.mkdirAsync 'test/live'
    .catch (error) ->
      debug "mkdir #{error.stack ? error}"
    .then ->
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
      fs.writeFileAsync 'test/live/freeswitch.xml', xml, 'utf-8'
    .catch (error) -> debug "write: #{error} in #{process.cwd()}"
    .then -> exec "docker kill #{p}"
    .catch -> true
    .then -> exec "docker rm #{p}"
    .catch -> true
    .then ->
      exec """
        docker run --net=host -d --name #{p} -v "#{pwd}/test/live:/opt/freeswitch/etc/freeswitch" shimaore/freeswitch:3.0.1 /opt/freeswitch/bin/freeswitch -nf -nosql -nonat -nonatmap -nocal -nort -c
      """
    .then -> start_server()
    .then (s) -> server = s
    .catch (error) ->
      debug "Start server failed: #{error}"
      throw error
    .then ->
      debug 'Start server OK, waiting...'
    .delay 10000
    .then ->
      debug 'Start server OK, done.'
      null

Server (Unit Under Test)
========================

    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    FS = require 'esl'
    options = null

    start_server = ->
      provisioning = null
      sip_domain_name = 'phone.local'
      Promise.resolve()
      .then -> PouchDB.destroy 'live-provisioning'
      .catch -> true
      .then -> PouchDB.destroy 'the_default_live_ruleset'
      .catch -> true
      .then ->
        provisioning = new PouchDB 'live-provisioning'
        provisioning.bulkDocs [
          {
            _id:'gateway:phone.local:gw1'
            type:'gateway'
            sip_domain_name:'phone.local'
            gwid:'gw1'
            address:"#{domain_name}:5064"
          }
          {
            _id:'ruleset:phone.local:default'
            type:'ruleset'
            sip_domain_name:'phone.local'
            groupid:'default'
            database:'the_default_live_ruleset'
          }
          {
            _id:'emergency:330112#brest'
            destination:'33156'
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
      .then ->
        ruleset = new PouchDB 'the_default_live_ruleset'
        ruleset.bulkDocs [
          {
            _id:'prefix:331'
            gwlist: [
              {gwid:'gw1'}
            ]
            attrs:
              cdr: 'foo-bar'
          }
          {
            _id:'prefix:330112'
            emergency:true
          }
        ]
      .catch (error) ->
        console.error "bulkDocs failed"
        throw error
      .then ->
        console.log 'Inserting Gateway Manager Couch'
        GatewayManager = require '../gateway_manager'
        provisioning.put GatewayManager.couch
      .then ->

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

        console.log 'Declaring Catcher'
        catcher = (require 'esl').server ->
          @command 'answer'
        catcher.listen 7004

        console.log 'Declaring Server'
        CallServer = require 'useful-wind/call_server'
        s = new CallServer options
        s.listen 7002
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
            destination = '330112'
            debug 'test2: originate'
            @api "originate [origination_caller_id_number=#{source},sip_h_X-CCNQ3-Routing=brest]sofia/huge-play-test-sender-ingress/sip:#{destination}@#{domain} &park"
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
          ready
        it 'should process a regular call', ->
          t = ready.then test1
          t.should.be.fulfilled
          t.should.eventually.equal true
        it 'should process a registrant call', ->
          t = ready.then test2
          t.should.be.fulfilled
          t.should.eventually.equal true

      after ->
        console.log "Stopping..."
        ready
        .then -> server?.stop()
        .then -> exec "docker logs #{p} > #{p}.log"
        .then -> exec "docker kill #{p}"
        .then -> exec "docker rm #{p}"
        .catch (error) ->
          console.log "`after` failed (ignored): #{error}"
          true
        null
