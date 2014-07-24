# LeapJS Network


Allows LeapJS frame data to be streamed between peers via WebRTC.  Remote frames and local frames are merged and rendered together.

See `index.html` for [live demo](http://leapmotion.github.io/leapjs-network).

```javascript
  controller.use('networking', {
    peer: new Peer({key: 'myapikey'}),  // WebRTC is handled by the PeerJS library & service
    plotter: new LeapDataPlotter() // Optional - graphed debugging outputs
  });

  controller.plugins.networking.connect('my-session-id');
```

The above code will cause the two newly connected peers to share all their frame data.

Frame objects are given universal IDs, such that hand id `4` might become hand id `4-wkejgb`.  Each hand is also given a
`userId` attribute.

Connected peers without the Leap, (or without their controller) will see remote hands.


![](https://s3.amazonaws.com/uploads.hipchat.com/28703/497504/6wKA7LD2agRg8Cl/Screenshot%202014-07-20%2013.43.19.png)


### A note on performance

CPU and network usage of this plugin are pretty good.  Being able to measure performance, both in terms of bandwidth and CPU usage, is extremely important when developing real-time applications, so check this yourself when used in your app.

To measure CPU usage (such as the data compression used here, or DOM manipulations), read this page: https://developer.leapmotion.com/leapjs/frame-loop

To measure network performance, check out the graphs included on `index.html`, as well as `chrome://webrtc-internals`. (va [SO post](http://stackoverflow.com/questions/24847640/how-to-measure-bandwidth-of-a-webrtc-data-channel))


### Roadmap

A few things could happen next:
 - More than two people on a page.  (this would require a relay server, or n^2 direct connections)
 - We could look for ways to reduce bandwidth usage, such as by sending frame diffs.
 - We could add a reliable data channel, for game-events to be synced.
