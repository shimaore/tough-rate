Default `carrierid` router plugin
=================================

    plugin = (entry) ->
      return unless entry.carrierid?
      @gateway_manager.resolve_carrier entry.carrierid
      .then (gateways) =>
        gateways.forEach (gateway) =>
          gateway.priority = 1

First we must sort the carrier entries using the local hostname preference.

          if gateway.local_gateway_first and @options.host? and gateway.host is @options.host
            gateway.priority += 0.5

        gateways.sort (a,b) -> a.priority - b.priority

And select only `try` entries where specified.

        count = gateways[0]?.try
        if count? and count > 0
          gateways = gateways[0...count]

        gateways

    plugin.title = 'Default `carrierid` plugin'
    plugin.description = "Injects the gateways described by the `carrierid` into the router's list of gateways."
    module.exports = plugin
