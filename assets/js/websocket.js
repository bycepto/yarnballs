const defaultLog = console.log;

const GOOD_COLOR = "#7ee081";
const WARN_COLOR = "#f2d56b";
const BAD_COLOR = "#ff7b72";
const NEUTRAL_COLOR = "#d7e3f0";
const COALESCE_WINDOW_MS = 5000;

const websocketUrl = () => {
  if (process.env.APP_MODE === "development") {
    return new URL(process.env.BASE_WS_URL);
  }

  const url = new URL("/ws", window.location.origin);
  url.protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  return url;
};

const colorByThresholds = (value, goodMax, warnMax) => {
  if (value == null) {
    return NEUTRAL_COLOR;
  }
  if (value <= goodMax) {
    return GOOD_COLOR;
  }
  if (value <= warnMax) {
    return WARN_COLOR;
  }
  return BAD_COLOR;
};

const colorByMinimums = (value, goodMin, warnMin) => {
  if (value == null) {
    return NEUTRAL_COLOR;
  }
  if (value >= goodMin) {
    return GOOD_COLOR;
  }
  if (value >= warnMin) {
    return WARN_COLOR;
  }
  return BAD_COLOR;
};

const colorByFrameBudget = (value, frameMs, goodFrames, warnFrames) => {
  if (value == null || frameMs == null || frameMs <= 0) {
    return NEUTRAL_COLOR;
  }
  return colorByThresholds(value, frameMs * goodFrames, frameMs * warnFrames);
};

const createMetrics = () => {
  const panel = document.createElement("div");
  panel.id = "yb-debug-metrics";
  Object.assign(panel.style, {
    position: "fixed",
    top: "12px",
    right: "12px",
    zIndex: "99999",
    width: "360px",
    padding: "10px 12px",
    background: "rgba(10, 16, 24, 0.88)",
    color: "#d7e3f0",
    font: "12px/1.45 ui-monospace, SFMono-Regular, Menlo, monospace",
    border: "1px solid rgba(160, 190, 220, 0.25)",
    borderRadius: "8px",
    boxShadow: "0 10px 30px rgba(0, 0, 0, 0.25)",
    pointerEvents: "none",
    boxSizing: "border-box",
    display: "none",
  });
  document.body.appendChild(panel);

  const title = document.createElement("div");
  title.textContent = "Yarnballs Debug";
  Object.assign(title.style, {
    marginBottom: "8px",
    fontWeight: "600",
  });
  panel.appendChild(title);

  const metricsGrid = document.createElement("div");
  Object.assign(metricsGrid.style, {
    display: "grid",
    gridTemplateColumns: "150px 1fr",
    columnGap: "10px",
    rowGap: "4px",
    alignItems: "baseline",
  });
  panel.appendChild(metricsGrid);

  const rows = [
    // websocket connection state
    ["socket", "socketStatus"],
    // number of joined websocket topics
    ["topics", "topics"],
    // observed browser frames per second
    ["fps", "fps"],
    // websocket round-trip time from client ping to server pong
    ["rtt", "rtt"],
    // snapshots received per second
    ["snapshots/s", "snapshotRate"],
    // raw websocket message size for the latest snapshot
    ["size", "snapshotBytes"],
    // age of the latest snapshot when it reached the browser
    ["server age", "snapshotAge"],
    // time from the most recent input send to the next snapshot arrival
    ["input->snapshot", "inputToSnapshot"],
    // time from the most recent input send to the first snapshot flush into Elm
    ["input->flush", "inputToFlush"],
    // time from snapshot receipt to the RAF-gated flush into Elm
    ["recv->flush", "receiveToFlush"],
    // time from snapshot receipt to the next paint opportunity after that flush
    ["recv->paint", "receiveToPaint"],
    // count of older pending snapshots replaced by newer ones over the recent window
    ["coalesced 5s", "coalescedRecent"],
    // percentage of recent snapshots that replaced an older pending snapshot
    ["coalesced %", "coalescedRatio"],
    // number of snapshots waiting to be flushed into Elm
    ["pending", "pendingSnapshots"],
    // number of subscribed websocket clients reported by the server
    ["server clients", "serverClientCount"],
    // number of active players reported by the server
    ["server players", "serverPlayerCount"],
    // authoritative simulation tick interval reported by the server
    ["server tick", "serverTick"],
    // snapshot broadcast interval reported by the server
    ["server broadcast", "serverBroadcast"],
    // monotonic sequence number of the latest snapshot
    ["snapshot seq", "snapshotSequence"],
  ];

  const rowElements = Object.fromEntries(
    rows.map(([label, key]) => {
      const labelEl = document.createElement("div");
      labelEl.textContent = label;
      labelEl.style.opacity = "0.8";

      const valueEl = document.createElement("div");
      valueEl.textContent = "";
      valueEl.style.color = NEUTRAL_COLOR;

      metricsGrid.appendChild(labelEl);
      metricsGrid.appendChild(valueEl);

      return [key, valueEl];
    }),
  );

  const state = {
    connected: false,
    joinedTopics: 0,
    fps: 0,
    frameMs: null,
    rttMs: null,
    snapshotRate: 0,
    snapshotBytes: 0,
    snapshotAgeMs: null,
    inputToSnapshotMs: null,
    inputToFlushMs: null,
    receiveToFlushMs: null,
    receiveToPaintMs: null,
    coalescedSnapshotTimes: [],
    pendingSnapshots: 0,
    serverClientCount: 0,
    serverPlayerCount: 0,
    serverBroadcastMs: 0,
    serverTickMs: 0,
    lastSequence: 0,
    frames: 0,
    lastFpsAt: performance.now(),
    lastFrameAt: null,
    snapshotTimes: [],
  };

  const setValue = (key, text, color = NEUTRAL_COLOR) => {
    rowElements[key].textContent = text;
    rowElements[key].style.color = color;
  };

  const trimRecentTimes = (times, now, windowMs) => {
    while (times.length > 0 && now - times[0] > windowMs) {
      times.shift();
    }
  };

  const render = () => {
    const now = performance.now();
    trimRecentTimes(state.snapshotTimes, now, COALESCE_WINDOW_MS);
    trimRecentTimes(state.coalescedSnapshotTimes, now, COALESCE_WINDOW_MS);

    const recentSnapshotCount = state.snapshotTimes.length;
    const recentCoalescedCount = state.coalescedSnapshotTimes.length;
    const recentCoalescedRatio =
      recentSnapshotCount > 0 ? (recentCoalescedCount / recentSnapshotCount) * 100 : null;

    setValue("socketStatus", state.connected ? "open" : "closed", state.connected ? GOOD_COLOR : BAD_COLOR);
    setValue("topics", String(state.joinedTopics), state.joinedTopics > 0 ? GOOD_COLOR : WARN_COLOR);
    setValue("fps", state.fps.toFixed(0), colorByMinimums(state.fps, 55, 45));
    setValue("rtt", formatMs(state.rttMs), colorByThresholds(state.rttMs, 60, 120));
    setValue("snapshotRate", state.snapshotRate.toFixed(1), colorByMinimums(state.snapshotRate, 20, 12));
    setValue("snapshotBytes", formatBytes(state.snapshotBytes), colorByThresholds(state.snapshotBytes, 5000, 12000));
    setValue("snapshotAge", formatMs(state.snapshotAgeMs), colorByThresholds(state.snapshotAgeMs, 40, 100));
    setValue("inputToSnapshot", formatMs(state.inputToSnapshotMs), colorByThresholds(state.inputToSnapshotMs, 40, 90));
    setValue("inputToFlush", formatMs(state.inputToFlushMs), colorByThresholds(state.inputToFlushMs, 50, 110));
    setValue("receiveToFlush", formatMs(state.receiveToFlushMs), colorByFrameBudget(state.receiveToFlushMs, state.frameMs, 0.75, 1.25));
    setValue("receiveToPaint", formatMs(state.receiveToPaintMs), colorByFrameBudget(state.receiveToPaintMs, state.frameMs, 1.5, 2.25));
    setValue("coalescedRecent", String(recentCoalescedCount), colorByThresholds(recentCoalescedCount, 3, 15));
    setValue("coalescedRatio", formatPercent(recentCoalescedRatio), colorByThresholds(recentCoalescedRatio, 5, 20));
    setValue("pendingSnapshots", String(state.pendingSnapshots), colorByThresholds(state.pendingSnapshots, 0, 1));
    setValue("serverClientCount", String(state.serverClientCount));
    setValue("serverPlayerCount", String(state.serverPlayerCount));
    setValue("serverTick", `${state.serverTickMs}ms`, colorByThresholds(state.serverTickMs, 16, 20));
    setValue("serverBroadcast", `${state.serverBroadcastMs}ms`, colorByThresholds(state.serverBroadcastMs, 33, 50));
    setValue("snapshotSequence", String(state.lastSequence));
  };

  const fpsLoop = () => {
    const now = performance.now();
    if (state.lastFrameAt != null) {
      const frameDelta = now - state.lastFrameAt;
      state.frameMs =
        state.frameMs == null ? frameDelta : state.frameMs * 0.9 + frameDelta * 0.1;
    }
    state.lastFrameAt = now;
    state.frames += 1;
    if (now - state.lastFpsAt >= 1000) {
      state.fps = (state.frames * 1000) / (now - state.lastFpsAt);
      state.frames = 0;
      state.lastFpsAt = now;
      render();
    }
    requestAnimationFrame(fpsLoop);
  };
  requestAnimationFrame(fpsLoop);
  render();

  return {
    noteInput() {
      state.lastInputAt = performance.now();
    },
    notePing() {
      state.lastPingAt = performance.now();
    },
    notePong(sentAtMs) {
      if (sentAtMs) {
        state.rttMs = Date.now() - sentAtMs;
      } else if (state.lastPingAt) {
        state.rttMs = performance.now() - state.lastPingAt;
      }
      render();
    },
    noteSnapshot({ serverTimeMs, sequence, snapshotBytes, clientCount, playerCount, broadcastIntervalMs, tickIntervalMs }) {
      const now = performance.now();
      const wallNow = Date.now();

      state.snapshotTimes.push(now);
      while (state.snapshotTimes.length > 0 && now - state.snapshotTimes[0] > 1000) {
        state.snapshotTimes.shift();
      }

      state.snapshotRate = state.snapshotTimes.length;
      state.snapshotBytes = snapshotBytes;
      state.snapshotAgeMs = serverTimeMs ? wallNow - serverTimeMs : null;
      state.serverClientCount = clientCount ?? state.serverClientCount;
      state.serverPlayerCount = playerCount ?? state.serverPlayerCount;
      state.serverBroadcastMs = broadcastIntervalMs ?? state.serverBroadcastMs;
      state.serverTickMs = tickIntervalMs ?? state.serverTickMs;
      state.lastSequence = sequence ?? state.lastSequence;

      if (state.lastInputAt != null) {
        state.inputToSnapshotMs = now - state.lastInputAt;
      }

      render();
    },
    noteStateQueued(replacedPending) {
      if (replacedPending) {
        state.coalescedSnapshotTimes.push(performance.now());
        state.pendingSnapshots = 1;
      } else {
        state.pendingSnapshots += 1;
      }
      render();
    },
    noteStateFlushed(queuedAt) {
      const flushAt = performance.now();
      state.pendingSnapshots = Math.max(0, state.pendingSnapshots - 1);
      state.receiveToFlushMs = flushAt - queuedAt;
      if (state.lastInputAt != null) {
        state.inputToFlushMs = flushAt - state.lastInputAt;
        state.lastInputAt = null;
      }
      requestAnimationFrame(() => {
        state.receiveToPaintMs = performance.now() - queuedAt;
        render();
      });
      render();
    },
    setConnected(connected) {
      state.connected = connected;
      render();
    },
    setJoinedTopics(count) {
      state.joinedTopics = count;
      render();
    },
    setVisible(visible) {
      panel.style.display = visible ? "block" : "none";
    },
    resetConnectionMetrics() {
      state.joinedTopics = 0;
      state.snapshotRate = 0;
      state.snapshotBytes = 0;
      state.snapshotAgeMs = null;
      state.inputToSnapshotMs = null;
      state.inputToFlushMs = null;
      state.receiveToFlushMs = null;
      state.receiveToPaintMs = null;
      state.coalescedSnapshotTimes = [];
      state.pendingSnapshots = 0;
      state.serverClientCount = 0;
      state.serverPlayerCount = 0;
      state.serverBroadcastMs = 0;
      state.serverTickMs = 0;
      state.lastSequence = 0;
      state.lastInputAt = null;
      state.snapshotTimes = [];
      render();
    },
    destroy() {
      panel.remove();
    },
  };
};

const formatMs = (value) => (value == null ? "n/a" : `${value.toFixed(1)}ms`);
const formatBytes = (value) => (value ? `${value}B` : "n/a");
const formatPercent = (value) => (value == null ? "n/a" : `${value.toFixed(1)}%`);

const setupWebSocket = (app, log = defaultLog) => {
  let socket = null;
  let channels = {};
  let pendingStateMessage = null;
  let pendingStateQueuedAt = 0;
  let stateFlushScheduled = false;
  let pingIntervalId = null;
  const leaveTopicPort = app.ports.leaveTopic;
  const confirmLeftTopicPort = app.ports.confirmLeftTopic;
  const metrics = createMetrics();

  const flushStateMessage = () => {
    stateFlushScheduled = false;

    if (!pendingStateMessage) {
      return;
    }

    metrics.noteStateFlushed(pendingStateQueuedAt);
    app.ports.messageReceiver.send(pendingStateMessage);
    pendingStateMessage = null;
    pendingStateQueuedAt = 0;
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

    metrics.noteInput();

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

    const url = websocketUrl();
    url.searchParams.set("token", token);
    socket = new WebSocket(url);

    socket.addEventListener("open", () => {
      app.ports.joinTopic.subscribe(joinTopic);
      if (leaveTopicPort) {
        leaveTopicPort.subscribe(leaveTopic);
      }
      app.ports.sendMessage.subscribe(sendMessage);

      app.ports.confirmSocketOpen.send(true);
      metrics.setConnected(true);
      metrics.resetConnectionMetrics();
      pingIntervalId = window.setInterval(() => {
        if (!socket || socket.readyState !== WebSocket.OPEN) {
          return;
        }

        const sentAtMs = Date.now();
        metrics.notePing();
        socket.send(
          JSON.stringify({
            type: "ping",
            sent_at_ms: sentAtMs,
          }),
        );
      }, 2000);
      log("Socket open!");
    });

    socket.addEventListener("message", ({ data }) => {
      const msg = JSON.parse(data);

      switch (msg.type) {
        case "join_ack":
          log(`joined topic: ${msg.topic}`);
          channels[msg.topic] = { events: msg.events || [] };
          metrics.setJoinedTopics(Object.keys(channels).length);
          app.ports.confirmJoinedTopic.send(msg.topic);
          break;

        case "message":
          const eventMessage = {
            event: msg.event,
            topic: msg.topic,
            payload: msg.payload,
          };

          if (msg.event === "requested_state") {
            const replacedPending = pendingStateMessage !== null;
            const snapshotMeta = msg.payload?.meta || {};
            metrics.noteSnapshot({
              serverTimeMs: snapshotMeta.server_time_ms,
              sequence: snapshotMeta.sequence,
              snapshotBytes: typeof data === "string" ? data.length : 0,
              clientCount: snapshotMeta.client_count,
              playerCount: snapshotMeta.player_count,
              broadcastIntervalMs: snapshotMeta.broadcast_interval_ms,
              tickIntervalMs: snapshotMeta.tick_interval_ms,
            });
            metrics.noteStateQueued(replacedPending);
            pendingStateMessage = eventMessage;
            pendingStateQueuedAt = performance.now();
            scheduleStateFlush();
            break;
          }

          app.ports.messageReceiver.send(eventMessage);
          break;

        case "pong":
          metrics.notePong(msg.echo_sent_at_ms);
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
      pendingStateQueuedAt = 0;
      stateFlushScheduled = false;
      if (pingIntervalId) {
        window.clearInterval(pingIntervalId);
        pingIntervalId = null;
      }

      app.ports.confirmSocketDisconnected.send(true);
      metrics.setConnected(false);
      metrics.resetConnectionMetrics();
      log("Socket disconnected!");
    });
  });

  return {
    setDebugMetricsVisible: metrics.setVisible,
  };
};

export { setupWebSocket };
