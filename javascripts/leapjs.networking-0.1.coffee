# plugin api:
# when page loads, a peer ID is gotten
# plugin receives Peer object on creation
# plugin has command to connect to another peer
# plugin emits it's own peer id?
# what happens on send if no other connections?
# should track who I'm connected to.

# Multicast would require a more complex setup, requiring a server or a slew of 1:1 connections
# see http://stackoverflow.com/questions/15504933/does-webrtc-allow-one-to-many-multicast-connections

Leap.plugin 'networking', (scope)->
  console.warn "No Peer supplied" unless scope.peer

  # currently: one connection to one other client
  scope.connection = null
  scope.sendFrames = false

  scope.peer.on 'error', ()->
    console.log 'peerjs error:', arguments

  scope.peer.on 'connection', (connection)->
    console.log 'someone likes me', connection
    scope.connection = connection
    scope.connectionEstablished()
    
  scope.connect = (id)->
    # connect can accept metadata, label, serialization type, and "reliable" flag.
    # false reliable by default
    # we should perhaps have two connections per peer-pair, so that game state data can be transmitted reliably independently.
    scope.connection = scope.peer.connect(id)
    scope.connectionEstablished()

  # we have this custom callback as the peerjs on connection only fires for incoming, not outbound.
  scope.connectionEstablished = ->
    console.log 'connection established', arguments

    scope.sendFrames = true

    # enable receiving of frame data
    scope.connection.on 'data', (data)->
      console.log 'received:', data
      # merge frame data here

  return {

    beforeFrameCreated: (frame)->
      return unless scope.sendFrames

      console.log 'send frame', frame.id
      scope.connection.send frame.id

    afterFrameCreated: (frame, rawFrameData) ->

  }
