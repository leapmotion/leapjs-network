class FrameSplicer
  constructor: (controller, userId, options)->
    @userId = userId
    @controller = controller
    @options = options

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
      @controller.processFrame(frame);

      window.requestAnimationFrame frameSplicer.remoteFrameLoop

  supplementLocalFrameData: (frameData) ->
    frameData.id += '-' + @userId
    frameData.sentAt = (new Date).getTime()

    for hand in frameData.hands
      # hand is the rootmost object of a player, esp. after frames get merged.
      hand.userId = @userId
      hand.id += '-' + @userId
#      console.assert typeof hand.id is "string", "Invalid hand id: " + hand.id

    for pointable in frameData.pointables
      pointable.id += '-' + @userId
      pointable.handId += '-' + @userId

  receiveRemoteFrame: (userId, frameData)->
    # don't add old frames
    previousFrameData = @remoteFrames[userId]

    return if previousFrameData and (previousFrameData.timestamp > frameData.timestamp)

    frameData.receivedAt = (new Date).getTime()

    if (@options.plotter)
      @plotFrameData(frameData, previousFrameData)

    @remoteFrames[userId] = frameData

  plotFrameData: (frameData, previousFrameData)->
    # this is the network latency - there is additional time waiting for the animation frame
    @options.plotter.plot 'network latency',
      frameData.receivedAt - frameData.sentAt,
      {
        units: 'ms',
        precision: 3
      }

    if previousFrameData
      @options.plotter.plot 'framerate (incoming)',
        1000 / (frameData.receivedAt - previousFrameData.receivedAt),
        {
          units: 'fps'
          precision: 3
        }


    @options.plotter.clear();
    @options.plotter.draw();


  # merges stockpiled frames with the given frame
  addRemoteFrameData: (frameData)->
    for userId, remoteFrame of @remoteFrames
      if (new Date).getTime() > (remoteFrame.sentAt + @options.frozenHandTimeout)
        # if timestamp hasn't been updated within 250ms timeout, get rid of it
        delete @remoteFrames[userId]
        break

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

