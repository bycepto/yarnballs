import { Elm } from "./Main.elm";
import { setupWebSocket } from "./websocket.js";
import "elm-canvas";

// Constants

const DISPLAY_NAME_KEY = "user_display_name";
const DURAK_SORT_TYPE_KEY = "durak_sort_type";
const REFRESH_TOKEN_KEY = "phx_refresh";

const DEV_MODE = import.meta.env.MODE == "development";

// log messages in dev mode
const log = (msg) => {
  if (DEV_MODE) {
    console.log(msg);
  }
};

// Local storage

const refreshToken = () => localStorage.getItem(REFRESH_TOKEN_KEY);

const setRefreshToken = (token) => {
  localStorage.setItem(REFRESH_TOKEN_KEY, token);
};

// Setup app

const app = Elm.Main.init({
  node: document.getElementById("main"),
  flags: {
    // One-time init - TODO: perhaps this can be specified as "config"?
    baseUrl: import.meta.env.VITE_BASE_API_URL,
    devMode: DEV_MODE,
    refreshToken: refreshToken(),
  },
});

// Session handlers

app.ports.storeRefreshToken.subscribe(setRefreshToken);
app.ports.clearRefreshToken.subscribe(() => {
  setRefreshToken(null);
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

// durak sort
const getSortType = () => localStorage.getItem(DURAK_SORT_TYPE_KEY);
const setSortType = (sortType) => {
  localStorage.setItem(DURAK_SORT_TYPE_KEY, sortType);
};
app.ports.requestDurakSort.subscribe(() => {
  app.ports.receiveDurakSort.send(getSortType());
});
app.ports.setDurakSort.subscribe(setSortType);

// Setup websocket

setupWebSocket(app, log);
