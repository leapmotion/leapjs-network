// Generated by CoffeeScript 1.7.1
(function() {
  var FrameSplicer;

  FrameSplicer = (function() {
    function FrameSplicer(controller, userId) {
      var frameSplicer;
      this.userId = userId;
      this.controller = controller;
      this.remoteFrames = {};
      console.assert(this.userId);
      frameSplicer = this;
      this.remoteFrameLoop = function() {
        var frame, frameData;
        if (this.controller.streaming()) {
          return;
        }
        frameData = {
          hands: [],
          pointables: []
        };
        frameSplicer.addRemoteFrameData(frameData);
        frame = new Leap.Frame(frameData);
        frameSplicer.supplementFinishedFrame(frame, frameData);
        window.controller.processFrame(frame);
        return window.requestAnimationFrame(frameSplicer.remoteFrameLoop);
      };
    }

    FrameSplicer.prototype.makeIdsUniversal = function(frameData) {
      var hand, pointable, _i, _j, _len, _len1, _ref, _ref1, _results;
      frameData.id += '-' + this.userId;
      _ref = frameData.hands;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        hand = _ref[_i];
        hand.userId = this.userId;
        hand.id += '-' + this.userId;
        console.assert(typeof hand.id === "string", "Invalid hand id: " + hand.id);
      }
      _ref1 = frameData.pointables;
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        pointable = _ref1[_j];
        pointable.id += '-' + this.userId;
        _results.push(pointable.handId += '-' + this.userId);
      }
      return _results;
    };

    FrameSplicer.prototype.receiveRemoteFrame = function(userId, frameData) {
      return this.remoteFrames[userId] = frameData;
    };

    FrameSplicer.prototype.addRemoteFrameData = function(frameData) {
      var hand, pointable, remoteFrame, userId, _i, _len, _ref, _ref1, _results;
      _ref = this.remoteFrames;
      _results = [];
      for (userId in _ref) {
        remoteFrame = _ref[userId];
        _ref1 = remoteFrame.hands;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          hand = _ref1[_i];
          frameData.hands.push(hand);
        }
        _results.push((function() {
          var _j, _len1, _ref2, _results1;
          _ref2 = remoteFrame.pointables;
          _results1 = [];
          for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
            pointable = _ref2[_j];
            _results1.push(frameData.pointables.push(pointable));
          }
          return _results1;
        })());
      }
      return _results;
    };

    FrameSplicer.prototype.supplementFinishedFrame = function(frame, rawFrameData) {
      var hand, i, pointable, _i, _j, _len, _len1, _ref, _ref1, _results;
      _ref = frame.hands;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        hand = _ref[i];
        hand.id = rawFrameData.hands[i].id;
        hand.userId = rawFrameData.hands[i].userId;
      }
      _ref1 = frame.pointables;
      _results = [];
      for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
        pointable = _ref1[i];
        _results.push(pointable.userId = rawFrameData.pointables[i].userId);
      }
      return _results;
    };

    return FrameSplicer;

  })();

  Leap.plugin('networking', function(scope) {
    var frameSplicer;
    if (!scope.peer) {
      console.warn("No Peer supplied");
      return;
    }
    scope.connection = null;
    scope.sendFrames = false;
    scope.maxSendRate = 100;
    frameSplicer = null;
    scope.peer.on('error', function(error) {
      console.log('peerjs error, not sending frames:', error, error.type);
      return scope.sendFrames = false;
    });
    scope.peer.on('connection', function(connection) {
      console.log("incoming " + connection.type + " connection from " + connection.peer);
      scope.connection = connection;
      return scope.connectionEstablished();
    });
    scope.connect = function(id) {
      scope.connection = scope.peer.connect(id);
      console.log("outgoing " + scope.connection.type + " connection to " + scope.connection.peer);
      return scope.connectionEstablished();
    };
    scope.connectionEstablished = function() {
      scope.sendFrames = true;
      return scope.connection.on('data', function(data) {
        if (data.frameData) {
          return frameSplicer.receiveRemoteFrame(scope.connection.peer, data.frameData);
        }
      });
    };
    scope.peer.on('open', (function(_this) {
      return function(id) {
        console.log("Peer ID received: " + id);
        return frameSplicer = new FrameSplicer(_this, id);
      };
    })(this));
    setTimeout(function() {
      return frameSplicer.remoteFrameLoop();
    }, 1000);
    scope.lastFrameSent = null;
    scope.shouldSendFrame = function(frameData) {
      if (!((new Date).getTime() > (scope.lastFrameSent + scope.maxSendRate))) {
        return false;
      }
      if (!(frameData.hands.length > 0)) {
        return false;
      }
      return true;
    };
    scope.sendFrame = function(frameData) {
      if (!scope.shouldSendFrame(frameData)) {
        return;
      }
      scope.connection.send({
        frameData: frameData
      });
      console.log('s');
      return scope.lastFrameSent = (new Date).getTime();
    };
    return {
      beforeFrameCreated: function(frameData) {
        if (!scope.sendFrames) {
          return;
        }
        console.assert(frameSplicer);
        frameSplicer.makeIdsUniversal(frameData);
        scope.sendFrame(frameData);
        return frameSplicer.addRemoteFrameData(frameData);
      },
      afterFrameCreated: FrameSplicer.prototype.supplementFinishedFrame
    };
  });

}).call(this);