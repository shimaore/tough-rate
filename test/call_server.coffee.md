Live test with FreeSwitch
=========================

    chai = require 'chai'
    chai.use require 'chai-as-promised'
    should = chai.should()

    Promise = require 'bluebird'
    real_exec = Promise.promisify (require 'child_process').exec
    pkg = require '../package.json'
    CaringBand = require 'caring-band'

Parameters for docker.io image
==============================

    process.chdir (require 'path').dirname __filename

    IMG = "#{pkg.name}-test"
    t = 'live'
    p = "#{IMG}-#{t}"
    DNS = null
    domain_name = '127.0.0.1'
    domain = "#{domain_name}:5062"
    exec = (cmd) ->
      console.log cmd
      real_exec cmd

    server = null

Setup
=====

    ready = Promise.resolve()
    .then -> exec "docker build -t #{p} #{t}/"
    .then -> exec "docker kill #{p}"
    .catch -> true
    .then -> exec "docker rm #{p}"
    .catch -> true
    .then ->
      exec "docker run --net=host -d --name #{p} #{p}"
    .then -> start_server()
    .then (s) -> server = s
    .catch (error) ->
      console.error "Start server failed"
      throw error
    .then ->
      console.log 'Start server OK, waiting...'
    .delay 10000
    .then ->
      console.log 'Start server OK, done.'
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
            _id:'rule:331'
            gwlist: [
              {gwid:'gw1'}
            ]
            attrs:
              cdr: 'foo-bar'
          }
          {
            _id:'rule:330112'
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
          profile: 'test-sender'
          host: 'example.net'
          ruleset_of: ruleset_of
          sip_domain_name: sip_domain_name
          statistics: new CaringBand()
          use: [
            'setup'
            'numeric'
            'response-handlers'
            'local-number'
            'ruleset'
            'emergency'
            'routes-gwid'
            'routes-carrierid'
            'routes-registrant'
            'flatten'
            'cdr'
            'call-handler'
            'use-ccnq-to-e164'
          ].map (m) ->
            require "../middleware/#{m}"

        console.log 'Declaring Server'
        CallServer = require 'useful-wind/call_server'
        s = new CallServer options
        s.listen 7002
        s

Test
====

    test1 = ->
      new Promise (resolve,reject) ->
        setTimeout reject, 4000
        try
          client = FS.client ->
            source = '1234'
            destination = '33142'
            @api "originate {origination_caller_id_number=#{source}}sofia/test-sender/sip:#{destination}@#{domain} &park"
            .then ->
              client.end()
              resolve true
            .catch (exception) ->
              client.end()
              reject exception
          client.on 'error', (data) ->
            console.dir 'test.on error':data
            client.end()
            reject new Error 'test error'
          client.connect 8022, '127.0.0.1'
          client
        catch exception
          reject exception

    test2 = ->
      new Promise (resolve,reject) ->
        setTimeout reject, 4000
        try
          client = FS.client ->
            source = '1235'
            destination = '330112'
            @api "originate [origination_caller_id_number=#{source},sip_h_X-CCNQ3-Routing=brest]sofia/test-sender/sip:#{destination}@#{domain} &park"
            .then ->
              client.end()
              resolve true
            .catch (exception) ->
              client.end()
              reject exception
          client.on 'error', (data) ->
            console.dir 'test2.on error':data
            client.end()
            reject new Error 'test error'
          client.connect 8022, '127.0.0.1'
          client
        catch exception
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
        .then -> exec "docker rmi #{p}"
        .catch (error) ->
          console.log "`after` failed (ignored): #{error}"
          true
        null
