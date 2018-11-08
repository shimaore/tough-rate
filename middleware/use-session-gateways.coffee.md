    pkg = require '../package'
    @name = "#{pkg.name}:middleware:use-session-gateways"
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

      return if @res.finalized()

      return unless @session.gateways?

      @res.gateways = @session.gateways

      return
