/*                    
 * LeapJS Network - v0.1.0 - 2014-12-10                    
 * http://github.com/leapmotion/leapjs-network/                    
 *                    
 * Copyright 2014 LeapMotion, Inc                    
 *                    
 * Licensed under the Apache License, Version 2.0 (the "License");                    
 * you may not use this file except in compliance with the License.                    
 * You may obtain a copy of the License at                    
 *                    
 *     http://www.apache.org/licenses/LICENSE-2.0                    
 *                    
 * Unless required by applicable law or agreed to in writing, software                    
 * distributed under the License is distributed on an "AS IS" BASIS,                    
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.                    
 * See the License for the specific language governing permissions and                    
 * limitations under the License.                    
 *                    
 */                    

(function() {
  "use strict";
  var FramePacker, FrameSplicer;

  FramePacker = (function() {
    function FramePacker(options) {
      this.packingStructure = [
        'id', 'timestamp', 'sentAt', {
          hands: [['id', 'type', 'direction', 'palmNormal', 'palmPosition', 'pinchStrength', 'grabStrength']]
        }, {
          pointables: [['id', 'direction', 'handId', 'length', 'tipPosition', 'carpPosition', 'mcpPosition', 'pipPosition', 'dipPosition', 'btipPosition', 'type']]
        }
      ];
    }

    FramePacker.prototype.pack = function(frameData) {
      return this.packData(this.packingStructure, frameData);
    };

    FramePacker.prototype.packData = function(structure, data) {
      var datum, key, nameOrHash, out, _i, _j, _len, _len1;
      out = [];
      for (_i = 0, _len = structure.length; _i < _len; _i++) {
        nameOrHash = structure[_i];
        if (typeof nameOrHash === "string") {
          out.push(data[nameOrHash]);
        } else if (Object.prototype.toString.call(nameOrHash) === "[object Array]") {
          for (_j = 0, _len1 = data.length; _j < _len1; _j++) {
            datum = data[_j];
            out.push(this.packData(nameOrHash, datum));
          }
        } else {
          for (key in nameOrHash) {
            break;
          }
          out.push(this.packData(nameOrHash[key], data[key]));
        }
      }
      return out;
    };

    FramePacker.prototype.unpack = function(frameData) {
      return this.unpackData(this.packingStructure, frameData);
    };

    FramePacker.prototype.unpackData = function(structure, data) {
      var datum, i, key, nameOrHash, out, subArray, _i, _j, _len, _len1;
      out = {};
      for (i = _i = 0, _len = structure.length; _i < _len; i = ++_i) {
        nameOrHash = structure[i];
        if (typeof nameOrHash === "string") {
          out[nameOrHash] = data[i];
        } else if (Object.prototype.toString.call(nameOrHash) === "[object Array]") {
          subArray = [];
          for (_j = 0, _len1 = data.length; _j < _len1; _j++) {
            datum = data[_j];
            subArray.push(this.unpackData(nameOrHash, datum));
          }
          return subArray;
        } else {
          for (key in nameOrHash) {
            break;
          }
          out[key] = this.unpackData(nameOrHash[key], data[i]);
        }
      }
      return out;
    };

    return FramePacker;

  })();

  FrameSplicer = (function() {
    function FrameSplicer(controller, userId, options) {
      var frameSplicer;
      this.userId = userId;
      this.controller = controller;
      this.options = options;
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
        this.controller.processFrame(frame);
        return window.requestAnimationFrame(frameSplicer.remoteFrameLoop);
      };
    }

    FrameSplicer.prototype.supplementLocalFrameData = function(frameData) {
      var hand, pointable, _i, _j, _len, _len1, _ref, _ref1, _results;
      frameData.id += '-' + this.userId;
      frameData.sentAt = (new Date).getTime();
      _ref = frameData.hands;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        hand = _ref[_i];
        hand.userId = this.userId;
        hand.id += '-' + this.userId;
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
      var previousFrameData;
      previousFrameData = this.remoteFrames[userId];
      if (previousFrameData && (previousFrameData.timestamp > frameData.timestamp)) {
        return;
      }
      frameData.receivedAt = (new Date).getTime();
      if (this.options.plotter) {
        this.plotFrameData(frameData, previousFrameData);
      }
      return this.remoteFrames[userId] = frameData;
    };

    FrameSplicer.prototype.plotFrameData = function(frameData, previousFrameData) {
      this.options.plotter.plot('network latency', frameData.receivedAt - frameData.sentAt, {
        units: 'ms',
        precision: 3
      });
      if (previousFrameData) {
        this.options.plotter.plot('framerate (incoming)', 1000 / (frameData.receivedAt - previousFrameData.receivedAt), {
          units: 'fps',
          precision: 3
        });
      }
      this.options.plotter.clear();
      return this.options.plotter.draw();
    };

    FrameSplicer.prototype.addRemoteFrameData = function(frameData) {
      var hand, pointable, remoteFrame, userId, _i, _len, _ref, _ref1, _results;
      _ref = this.remoteFrames;
      _results = [];
      for (userId in _ref) {
        remoteFrame = _ref[userId];
        if ((new Date).getTime() > (remoteFrame.sentAt + this.options.frozenHandTimeout)) {
          delete this.remoteFrames[userId];
          break;
        }
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
    var framePacker, frameSplicer,
      _this = this;
    if (!scope.peer) {
      console.warn("No Peer supplied");
      return;
    }
    scope.connection = null;
    scope.sendFrames = false;
    scope.maxSendRate = 60;
    scope.frozenHandTimeout = 250;
    frameSplicer = null;
    framePacker = new FramePacker;
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
        var frameData;
        if (data.frameData) {
          frameData = framePacker.unpack(data.frameData);
          return frameSplicer.receiveRemoteFrame(scope.connection.peer, frameData);
        }
      });
    };
    scope.peer.on('open', function(id) {
      console.log("Peer ID received: " + id);
      frameSplicer = new FrameSplicer(_this, id, scope);
      return setTimeout(function() {
        return frameSplicer.remoteFrameLoop();
      }, 1000);
    });
    controller.on('streamingStopped', function() {
      if (frameSplicer) {
        return frameSplicer.remoteFrameLoop();
      }
    });
    scope.lastFrame = null;
    scope.shouldSendFrame = function(frameData) {
      if (scope.lastFrame && (scope.lastFrame.sentAt + scope.maxSendRate) > (new Date).getTime()) {
        return false;
      }
      if (!scope.lastFrame && frameData.hands.length === 0) {
        return false;
      }
      if (scope.lastFrame && scope.lastFrame.hands.length === 0 && frameData.hands.length === 0) {
        return false;
      }
      return true;
    };
    scope.sendFrame = function(frameData) {
      var blob;
      if (!scope.shouldSendFrame(frameData)) {
        return;
      }
      blob = scope.connection.send({
        frameData: framePacker.pack(frameData)
      });
      scope.plotter.plot('frame size (outgoing)', blob.size / 1024, {
        units: 'kb',
        precision: 3
      });
      scope.plotter.clear();
      scope.plotter.draw();
      return scope.lastFrame = frameData;
    };
    return {
      beforeFrameCreated: function(frameData) {
        if (!scope.sendFrames) {
          return;
        }
        frameSplicer.supplementLocalFrameData(frameData);
        scope.sendFrame(frameData);
        return frameSplicer.addRemoteFrameData(frameData);
      },
      afterFrameCreated: FrameSplicer.prototype.supplementFinishedFrame
    };
  });

}).call(this);
