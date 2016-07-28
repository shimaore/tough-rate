    Promise = require 'bluebird'
    chai = require 'chai'
    chai.should()
    require 'chai-as-promised'
    fs = Promise.promisifyAll require 'fs'

    before ->
      # Write a file in server.json that contains  "acls": { "default": [ "172.17.42.0/8" ] }

    it.skip 'should write proper ACLS', ->
      run = require '../config.coffee.md'
      options = require './example.json'
      run options
      .then ->
        fs.readFileAsync '../conf/acl.conf.xml', 'utf-8'
        .should.eventually.equal '<list name="default" default="deny"><node type="allow" cidr="172.17.42.0/8" /></list>\n'
