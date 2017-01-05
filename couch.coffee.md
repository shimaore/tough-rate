    pkg = require './package.json'
    replication_filter_doc = require 'nimble-direction/replication_filter_doc'

The design document that must be installed on the master databases in order for tough-rate hosts to replicate the proper data.

    replicate_types = [
      'carrier'
      'config'
      # 'domain'
      'emergency'
      'endpoint'
      'gateway'
      'host'
      # 'list'
      'location'
      'number'
      # 'number_domain'
      'ruleset'
    ]

    @couch = replication_filter_doc pkg, replicate_types
