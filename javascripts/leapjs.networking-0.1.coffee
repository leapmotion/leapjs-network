# plugin api:
# when page loads, a peer ID is gotten
# plugin receives Peer object on creation
# plugin has command to connect to another peer
# plugin emits it's own peer id?
# what happens on send if no other connections?
# should track who I'm connected to.

# Multicast would require a more complex setup, requiring a server or a slew of 1:1 connections
# see http://stackoverflow.com/questions/15504933/does-webrtc-allow-one-to-many-multicast-connections

# hit list / todo list
# minimize CPU/maximize frame rate
# graph streaming data
# make reconnection-robust
# allow observers

# note: could this be better factored as an alternative protocol?
class FrameSplicer
  constructor: (controller, userId)->
    @userId = userId
    @controller = controller

    @remoteFrames = {}
    console.assert @userId

    frameSplicer = this

    @remoteFrameLoop = ->
      # this method is similar to the LeapJS protocol

      return if @controller.streaming()

      # stub which gets frames merged to it:
      frameData = {
        hands: []
        pointables: []
      }

      frameSplicer.addRemoteFrameData(frameData)

      frame = new Leap.Frame(frameData);

      frameSplicer.supplementFinishedFrame(frame, frameData)

      # this calls immediately, as there is no frame loop running for Leap-less clients.
      window.controller.processFrame(frame);

      window.requestAnimationFrame frameSplicer.remoteFrameLoop

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

  receiveRemoteFrame: (userId, frameData)->
    # don't add old frames
    return if @remoteFrames[userId] and (@remoteFrames[userId].timestamp > frameData.timestamp)

    @remoteFrames[userId] = frameData

  # merges stockpiled frames with the given frame
  addRemoteFrameData: (frameData)->
    for userId, remoteFrame of @remoteFrames
      # need if hands check here?
      for hand in remoteFrame.hands
        frameData.hands.push hand

      for pointable in remoteFrame.pointables
        frameData.pointables.push pointable

  supplementFinishedFrame: (frame, rawFrameData) ->
    # note that this violates certain speed javascript principles:
    # properties should not be added to objects "on the fly" after construction

    for hand, i in frame.hands
      hand.id = rawFrameData.hands[i].id
      hand.userId = rawFrameData.hands[i].userId

    for pointable, i in frame.pointables
      pointable.userId = rawFrameData.pointables[i].userId




# designed to only handle one connection.
Leap.plugin 'networking', (scope)->

  unless scope.peer
    console.warn "No Peer supplied"
    return

  # currently: one connection to one other client
  scope.connection = null
  scope.sendFrames = false
  scope.maxSendRate = 100 # ms

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
      if data.frameData
        frameSplicer.receiveRemoteFrame(scope.connection.peer, data.frameData)



  scope.peer.on 'open', (id)=>
    console.log "Peer ID received: #{id}"
    frameSplicer = new FrameSplicer(this, id)

  # give a second to begin local streaming  connect before immediately starting our own animation Loop
  setTimeout  ->
    frameSplicer.remoteFrameLoop();
  , 1000

  scope.lastFrameSent = null

  scope.shouldSendFrame = (frameData)->
    # maximum 1 fps:
    return false unless (new Date).getTime() > (scope.lastFrameSent + scope.maxSendRate)

    return false unless frameData.hands.length > 0

    return true

  scope.sendFrame = (frameData)->
    return unless scope.shouldSendFrame(frameData)

    scope.connection.send {
      frameData: frameData
    }
    console.log 's'

    scope.lastFrameSent = (new Date).getTime()




  return {

    beforeFrameCreated: (frameData)->
      return unless scope.sendFrames

      # frameSplicer should always be created before the connection is done.
      console.assert frameSplicer

      frameSplicer.makeIdsUniversal(frameData)

      scope.sendFrame(frameData)

      # doesn't clear remote person's frame, so they'll appear to freeze if they lag, but won't disappear
      frameSplicer.addRemoteFrameData(frameData)


    afterFrameCreated: FrameSplicer.prototype.supplementFinishedFrame

  }
