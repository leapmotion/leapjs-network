# LeapJS Network


Allows LeapJS frame data to be streamed between peers via WebRTC.  Remote frames and local frames are merged and rendered together.

See `index.html` for demo.

```javascript
  controller.use('networking', {
    peer: new Peer({key: 'ah7pg4vez7kz9f6r'}),  // WebRTC is handled by the PeerJS library & service
    plotter: new LeapDataPlotter()
  });

  controller.plugins.networking.connect('my-session-id');
```

The above code will cause the two newly connected peers to share all their frame data.

Frame objects are given universal IDs, such that hand id `4` might become hand id `4-wkejgb`.  Each hand is also given a
`userId` attribute.

Connected peers without the Leap, (or without their controller) will see remote hands.


![](https://s3.amazonaws.com/uploads.hipchat.com/28703/497504/6wKA7LD2agRg8Cl/Screenshot%202014-07-20%2013.43.19.png)
