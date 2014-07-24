"use strict"

# turns a frame from a JSON blog to an array, specifically formatted, with a subset of frameData
# ripped from playback
class FramePacker

  constructor: (options)->
    # see https://github.com/leapmotion/leapjs/blob/master/Leap_JSON.rst
    @packingStructure = [
      'id',
      'timestamp',
      'sentAt',
      {hands: [[
        'id',
        'type',
        'direction',
        'palmNormal',
        'palmPosition',
        'pinchStrength',
        'grabStrength',
      ]]},
      {pointables: [[
        'id',
        'direction',
        'handId',
        'length',
        'tipPosition',
        'carpPosition',
        'mcpPosition',
        'pipPosition',
        'dipPosition',
        'btipPosition',
        'type'
      ]]}
    ];

  pack: (frameData)->
    @packData(@packingStructure, frameData)

  packData: (structure, data)->
    out = []

    for nameOrHash in structure

      # e.g., nameOrHash is either 'id' or {hand: [...]}
      if typeof nameOrHash is "string"

        out.push data[nameOrHash]

      else if Object::toString.call(nameOrHash) is "[object Array]"

        # nested array, such as hands or fingers

        for datum in data
          out.push @packData(nameOrHash, datum)

      else # key-value (nested object) such as interactionBox
        for key of nameOrHash
          break

        out.push @packData(nameOrHash[key], data[key])

    out

  unpack: (frameData) ->
    @unpackData(@packingStructure, frameData)

  unpackData: (structure, data) ->
    out = {}

    for nameOrHash, i in structure
      # e.g., nameOrHash is either 'id' or {hand: [...]}

      if typeof nameOrHash is "string"

        out[nameOrHash] = data[i]

      else if Object::toString.call(nameOrHash) is "[object Array]"

        # nested array, such as hands or fingers
        # nameOrHash ["id", "direction", "palmNormal", "palmPosition", "palmVelocity"]
        # data [ [ 31, [vec3], [vec3], ...] ]
        subArray = []

        for datum in data
          subArray.push @unpackData(nameOrHash, datum)

        return subArray

      else # key-value (nested object) such as interactionBox

        for key of nameOrHash
          break

        out[key] = @unpackData(nameOrHash[key], data[i])

    out