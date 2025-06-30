import { Elm } from "./Main.elm";
import { setupWebSocket } from "./websocket.js";
import "elm-canvas";

// Constants

const DISPLAY_NAME_KEY = "user_display_name";
const ACCESS_TOKEN_KEY = "phx_access";

const DEV_MODE = process.env.PHX_MODE == "development";

// log messages in dev mode
const log = (msg) => {
  if (DEV_MODE) {
    console.log(msg);
  }
};

// Local storage

const accessToken = () => localStorage.getItem(ACCESS_TOKEN_KEY);

const setAccessToken = (token) => {
  localStorage.setItem(ACCESS_TOKEN_KEY, token);
};

// Setup app

const app = Elm.Main.init({
  node: document.getElementById("main"),
  flags: {
    // One-time init - TODO: perhaps this can be specified as "config"?
    baseUrl: process.env.PHX_BASE_HTTP_URL,
    devMode: DEV_MODE,
    accessToken: accessToken(),
  },
});

// Session handlers

app.ports.storeAccessToken.subscribe(setAccessToken);
app.ports.clearAccessToken.subscribe(() => {
  setAccessToken(null);
});

// User settings

// display name
const displayName = () => localStorage.getItem(DISPLAY_NAME_KEY);
const setDisplayName = (name) => {
  localStorage.setItem(DISPLAY_NAME_KEY, name);
};
app.ports.getDisplayName.subscribe(() => {
  app.ports.displayNameReceiver.send(displayName());
});
app.ports.setDisplayName.subscribe(setDisplayName);

// Setup websocket

setupWebSocket(app, log);
