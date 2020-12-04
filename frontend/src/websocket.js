import { Socket, Presence } from 'phoenix';

// TODO: separate handler for each topic
// TODO: can we just let all topics in and let Elm handle the filtering?
// One solution is to have the channel send a list of valid events after the
// client joins it.
const events = [
  'created_room',
  'created_room_with_bots',
  'game_event',
  'requested_history',
  'requested_last_state',
  'joined_room',
  'phx_join',
  'phx_leave',
  'phx_reply',
];

const defaultLog = console.log;

const setupWebSocket = (app, log = defaultLog) => {
  let socket = null;
  let channels = {};
  let presences = {};

  // functions to subscribe / unsubscribe on connect / disconnect

  const joinTopic = (topic) => {
    if (topic in channels) {
      // Already joined
      log(`tried to join existing channel: ${topic}`);
      return;
    }

    const channel = socket.channel(topic);

    events.forEach((evt) => {
      // TODO: separate handler for each topic
      channel.on(evt, (msg) => {
        app.ports.messageReceiver.send({
          event: evt,
          topic: topic,
          payload: msg,
        });
      }); // => returns ref
    });

    // TODO: check if join is successful
    channel.join().receive('ok', (info) => {
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

      // Update presence
      channel.on('presence_state', (state) => {
        presences = Presence.syncState(presences, state);
        log('presence_state', presences);
        app.ports.presenceReceiver.send(presences);
      });

      channel.on('presence_diff', (diff) => {
        presences = Presence.syncDiff(presences, diff);
        log('presence_diff', presences);
        app.ports.presenceReceiver.send(presences);
      });
    });
  };

  const leaveTopic = (topic) => {
    if (topic in channels) {
      channels[topic].leave().receive('ok', () => {
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
      .receive('ok', (payload) => log('phoenix replied:', payload))
      .receive('error', (err) => log('phoenix errored', err))
      .receive('timeout', () => log('timed out pushing'));
  };

  // Connect / disconnect

  app.ports.disconnectFromSocket.subscribe(() => {
    if (socket) {
      // TODO: what happens if the socket is already disconnected?
      socket.disconnect();
    }
  });

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
      app.ports.leaveTopic.subscribe(leaveTopic);
      app.ports.sendMessage.subscribe(sendMessage);

      app.ports.confirmSocketOpen.send(true);
      log('Socket open!');
    });

    socket.onClose(() => {
      app.ports.joinTopic.unsubscribe(joinTopic);
      app.ports.leaveTopic.unsubscribe(leaveTopic);
      app.ports.sendMessage.unsubscribe(sendMessage);

      for (const topic in channels) {
        // TODO: Confirm left?
        channels[topic].leave();
      }
      channels = {};

      app.ports.confirmSocketDisconnected.send(true);
      log('Socket disconnected!');
    });
  });
};

export { setupWebSocket };
