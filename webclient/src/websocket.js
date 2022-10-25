import { Socket } from "phoenix";

const defaultLog = console.log;

const setupWebSocket = (app, log = defaultLog) => {
  let socket = null;
  let channels = {};

  const joinTopic = (topic) => {
    if (topic in channels) {
      // Already joined
      log(`tried to join existing channel: ${topic}`);
      return;
    }

    const channel = socket.channel(topic);

    // TODO: check if join is successful
    channel.join().receive("ok", (info) => {
      // Add channel and report to app
      // TODO: can we just use presence for this?
      log(`joined topic: ${topic}`);
      channels[topic] = channel;
      app.ports.confirmJoinedTopic.send(topic);

      // Channels will tell us what events we should listen for.
      if (info.events) {
        info.events.forEach((event) => {
          channel.on(event, (payload) => {
            log(`sending event to elm: ${event}`);
            app.ports.messageReceiver.send({
              event: event,
              topic: topic,
              payload: payload,
            });
          });
        });
      }
    });
  };

  const leaveTopic = (topic) => {
    if (topic in channels) {
      channels[topic].leave().receive("ok", () => {
        // Remove channel and report to app
        log(`left topic:${topic}`);
        delete channels[topic];
        app.ports.confirmLeftTopic.send(topic);
      });
    }
  };

  const sendMessage = ({ topic, event, payload }) => {
    // TODO: ensure topic exists
    channels[topic]
      .push(event, payload)
      .receive("ok", (payload) => log("phoenix replied:", payload))
      .receive("error", (err) => log("phoenix errored", err))
      .receive("timeout", () => log("timed out pushing"));
  };

  // // Connect & disconnect
  //
  // app.ports.disconnectFromSocket.subscribe(() => {
  //   if (socket) {
  //     // TODO: what happens if the socket is already disconnected?
  //     socket.disconnect();
  //   }
  // });

  app.ports.connectToSocket.subscribe(({ token }) => {
    if (socket && socket.isConnected()) {
      app.ports.confirmSocketOpen.send(true);
      return;
    }

    socket = new Socket(import.meta.env.VITE_BASE_WS_URL, {
      params: { token },
    });
    socket.connect();

    socket.onOpen(() => {
      app.ports.joinTopic.subscribe(joinTopic);
      // app.ports.leaveTopic.subscribe(leaveTopic);
      app.ports.sendMessage.subscribe(sendMessage);

      app.ports.confirmSocketOpen.send(true);
      log("Socket open!");
    });

    socket.onClose(() => {
      app.ports.joinTopic.unsubscribe(joinTopic);
      // app.ports.leaveTopic.unsubscribe(leaveTopic);
      app.ports.sendMessage.unsubscribe(sendMessage);

      for (const topic in channels) {
        // TODO: Confirm left?
        channels[topic].leave();
      }
      channels = {};

      app.ports.confirmSocketDisconnected.send(true);
      log("Socket disconnected!");
    });
  });
};

export { setupWebSocket };
