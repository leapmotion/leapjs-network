# plugin api:
# when page loads, a peer ID is gotten
# plugin receives Peer object on creation
# plugin has command to connect to another peer
# plugin emits it's own peer id?
# what happens on send if no other connections?
# should track who I'm connected to.

# Multicast would require a more complex setup, requiring a server or a slew of 1:1 connections
# see http://stackoverflow.com/questions/15504933/does-webrtc-allow-one-to-many-multicast-connections

# note: could this be better factored as an alternative protocol?
class FrameSplicer
  constructor: (userId)->
    @userId = userId
    console.assert @userId

  makeIdsUniversal: (frameData) ->
    frameData.id += '-' + @userId

    for hand in frameData.hands
      # hand is the rootmost object of a player, esp. after frames get merged.
      hand.userId = @userId
      hand.id += '-' + @userId
      console.assert typeof hand.id is "string", "Invalid hand id: " + hand.id

    for pointable in frameData.pointables
      pointable.id += '-' + @userId
      pointable.handId += '-' + @userId

# designed to only handle one connection.
Leap.plugin 'networking', (scope)->
  console.warn "No Peer supplied" unless scope.peer

  # currently: one connection to one other client
  scope.connection = null
  scope.sendFrames = false

  frameSplicer = null

  scope.peer.on 'error', (error)->
    console.log 'peerjs error, not sending frames:', error, error.type
    scope.sendFrames = false

  scope.peer.on 'connection', (connection)->
    console.log "incoming #{connection.type} connection from #{connection.peer}"
    scope.connection = connection
    scope.connectionEstablished()

  scope.connect = (id)->
    # connect can accept metadata, label, serialization type, and "reliable" flag.
    # false reliable by default
    # we should perhaps have two connections per peer-pair, so that game state data can be transmitted reliably independently.
    scope.connection = scope.peer.connect(id)
    console.log "outgoing #{scope.connection.type} connection to #{scope.connection.peer}"
    scope.connectionEstablished()

  # we have this custom callback as the peerjs on connection only fires for incoming, not outbound.
  scope.connectionEstablished = ->

    scope.sendFrames = true

    # enable receiving of frame data
    scope.connection.on 'data', (data)->
      console.log 'received:', data

      # if receiving frame data and not connected, give to the splicer and then render it
      # perhaps the splicer has it's own animate loop
      # should work with LeapJS's


      # merge frame data here

  scope.peer.on 'open', (id)->
    frameSplicer = new FrameSplicer(id)



  return {

    beforeFrameCreated: (frameData)->
      return unless scope.sendFrames

      # frameSplicer should always be created before the connection is done.
      console.assert frameSplicer

      frameSplicer.makeIdsUniversal(frameData)

      console.log 'send frame', frameData.id
      scope.connection.send frameData.id

    # operates on top of spliced frame from multiple peers because uses raw frame data

    # splicer needs to merge frame on its own animation loop
    # can we force LeapJS to render every one of what it thinks to be "device frames", thereby allowing us full-control
    # of render rate?
    # pretty much re-implementing LeapJS's frame loop.
    # need to takeover the behavior from the plugin?
    # for now, manually specify that the controller must be using frameEventName: DeviceFrame
    afterFrameCreated: (frame, rawFrameData) ->
      # note that this violates certain speed javascript principles:
      # properties should not be added to objects "on the fly" after construction

      for hand, i in frame.hands
        hand.id = rawFrameData.hands[i].id
        hand.userId = rawFrameData.hands[i].userId

      for pointable, i in frame.pointables
        pointable.userId = rawFrameData.pointables[i].userId

  }
