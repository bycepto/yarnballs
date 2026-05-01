const defaultLog = console.log;

const setupWebSocket = (app, log = defaultLog) => {
  let socket = null;
  let channels = {};
  let pendingStateMessage = null;
  let stateFlushScheduled = false;
  const leaveTopicPort = app.ports.leaveTopic;
  const confirmLeftTopicPort = app.ports.confirmLeftTopic;

  const flushStateMessage = () => {
    stateFlushScheduled = false;

    if (!pendingStateMessage) {
      return;
    }

    app.ports.messageReceiver.send(pendingStateMessage);
    pendingStateMessage = null;
  };

  const scheduleStateFlush = () => {
    if (stateFlushScheduled) {
      return;
    }

    stateFlushScheduled = true;
    requestAnimationFrame(flushStateMessage);
  };

  const joinTopic = (topic) => {
    if (topic in channels) {
      // Already joined
      log(`tried to join existing channel: ${topic}`);
      return;
    }

    socket.send(
      JSON.stringify({
        type: "join",
        topic,
      }),
    );
  };

  const leaveTopic = (topic) => {
    if (topic in channels) {
      socket.send(
        JSON.stringify({
          type: "leave",
          topic,
        }),
      );
      log(`left topic:${topic}`);
      delete channels[topic];
      if (confirmLeftTopicPort) {
        confirmLeftTopicPort.send(topic);
      }
    }
  };

  const sendMessage = ({ topic, event, payload }) => {
    if (!(topic in channels)) {
      log(`cannot send message to topic before join: ${topic}`);
      return;
    }

    socket.send(
      JSON.stringify({
        type: "event",
        topic,
        event,
        payload,
      }),
    );
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
    if (socket && socket.readyState === WebSocket.OPEN) {
      app.ports.confirmSocketOpen.send(true);
      return;
    }

    const url = new URL(process.env.BASE_WS_URL);
    url.searchParams.set("token", token);
    socket = new WebSocket(url);

    socket.addEventListener("open", () => {
      app.ports.joinTopic.subscribe(joinTopic);
      if (leaveTopicPort) {
        leaveTopicPort.subscribe(leaveTopic);
      }
      app.ports.sendMessage.subscribe(sendMessage);

      app.ports.confirmSocketOpen.send(true);
      log("Socket open!");
    });

    socket.addEventListener("message", ({ data }) => {
      const msg = JSON.parse(data);

      switch (msg.type) {
        case "join_ack":
          log(`joined topic: ${msg.topic}`);
          channels[msg.topic] = { events: msg.events || [] };
          app.ports.confirmJoinedTopic.send(msg.topic);
          break;

        case "message":
          const eventMessage = {
            event: msg.event,
            topic: msg.topic,
            payload: msg.payload,
          };

          if (msg.event === "requested_state") {
            pendingStateMessage = eventMessage;
            scheduleStateFlush();
            break;
          }

          app.ports.messageReceiver.send(eventMessage);
          break;

        case "error":
          log(`websocket error: ${msg.error}`);
          break;

        default:
          log(`ignored websocket message type: ${msg.type}`);
      }
    });

    socket.addEventListener("close", () => {
      app.ports.joinTopic.unsubscribe(joinTopic);
      if (leaveTopicPort) {
        leaveTopicPort.unsubscribe(leaveTopic);
      }
      app.ports.sendMessage.unsubscribe(sendMessage);

      for (const topic in channels) {
        delete channels[topic];
      }
      channels = {};
      pendingStateMessage = null;
      stateFlushScheduled = false;

      app.ports.confirmSocketDisconnected.send(true);
      log("Socket disconnected!");
    });
  });
};

export { setupWebSocket };
