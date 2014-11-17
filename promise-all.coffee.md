    module.exports = (array,fun) ->
      Promise.all array.map (entry) ->
        if isArray entry
          Promise.all entry.map fun
        else
          fun entry

    Promise = require 'bluebird'
    {isArray} = require 'util'
