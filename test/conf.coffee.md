    {expect} = require 'chai'

    it 'The FreeSwitch configuration', ->
      options = require './example.json'
      config = (require '../conf/freeswitch') options

      expected_config = (fs.readFileSync 'test/expected_config.xml','utf8').replace /\n */g, '\n'
      expect(config).to.equal expected_config
