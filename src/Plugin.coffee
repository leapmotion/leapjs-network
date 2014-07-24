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


# designed to only handle one 1:1 connection.
Leap.plugin 'networking', (scope)->


  unless scope.peer
    console.warn "No Peer supplied"
    return

  # currently: one connection to one other client
  scope.connection = null
  scope.sendFrames = false
  scope.maxSendRate = 60 # ms
  scope.frozenHandTimeout = 250 # ms

  frameSplicer = null
  framePacker = new FramePacker

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
  # note that WebRTC data doesn't support blob type yet, which causes expensive packing
  # https://bugs.webkit.org/show_bug.cgi?id=112314
  # see https://github.com/peers/peerjs/blob/master/lib/dataconnection.js#L182-L183
  # and util.supports.binaryBlob
  scope.connectionEstablished = ->

    scope.sendFrames = true

    # enable receiving of frame data
    scope.connection.on 'data', (data)->

      if data.frameData

        # does this take time? Or save time?
        frameData = framePacker.unpack(data.frameData)

        frameSplicer.receiveRemoteFrame(scope.connection.peer, frameData)



  scope.peer.on 'open', (id)=>
    console.log "Peer ID received: #{id}"
    frameSplicer = new FrameSplicer(this, id, scope)

    # give a second to begin local streaming  connect before immediately starting our own animation Loop
    setTimeout  ->
      frameSplicer.remoteFrameLoop();
    , 1000

  controller.on 'streamingStopped', ->
    frameSplicer.remoteFrameLoop();



  # begin lastFrame logic.  Should be in its own class?

  scope.lastFrame = null

  scope.shouldSendFrame = (frameData)->
    # maximum fps:
    return false if scope.lastFrame and (scope.lastFrame.sentAt + scope.maxSendRate) > (new Date).getTime()
    # no empty frames:
    return false if !scope.lastFrame and frameData.hands.length == 0

    return false if  scope.lastFrame and scope.lastFrame.hands.length == 0 and frameData.hands.length == 0

    return true

  scope.sendFrame = (frameData)->
    return unless scope.shouldSendFrame(frameData)

    # it seems non-trivial to get the size of the ArrayBuffer on the receiving end, as datachannel's onmessage event.data
    # appears to arrive as an ArrayBuffer with indeterminate length.
    # for now we read the outgoing blob byte size
    # it is unknown how this relates to actual size-over wire.
    blob = scope.connection.send {
      frameData: framePacker.pack(frameData)
    }
    # two graphs:
    # kb/frame
    # fb/s
    # we call plotter clear and draw here
    # not sure what will happen when both receiving and sending call to update the graph :P

    scope.plotter.plot 'frame size (outgoing)',
      blob.size / 1024,
      {
        units: 'kb'
        precision: 3
      }

    scope.plotter.clear()
    scope.plotter.draw()


    scope.lastFrame = frameData

  # end lastFrame logic.


  # return controller callbacks:
  return {

    beforeFrameCreated: (frameData)->
      return unless scope.sendFrames

      # frameSplicer should always be created before the connection is done.
      console.assert frameSplicer

      frameSplicer.supplementLocalFrameData(frameData)

      scope.sendFrame(frameData)

      # doesn't clear remote person's frame, so they'll appear to freeze if they lag, but won't disappear
      frameSplicer.addRemoteFrameData(frameData)


    afterFrameCreated: FrameSplicer.prototype.supplementFinishedFrame

  }
