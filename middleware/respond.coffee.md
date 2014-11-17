Response Middleware
===================

Normally called late in the game, it sends out a response if one is required.

    module.exports = ->

      middleware = ->

        return unless @response

        @logger "Sending #{@response} response."
        @call.command 'respond', @response
