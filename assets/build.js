const esbuild = require("esbuild");
const ElmPlugin = require('esbuild-plugin-elm');

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const deploy = args.includes('--deploy');

const loader = {
  '.ico': 'file',
  '.png': 'file'
};

const plugins = [
  ElmPlugin(),
];

let opts = {
  assetNames: "[name]",
  entryPoints: ["js/app.js", "css/app.css", "images/*"],
  inject: ["js/websocket.js"],
  bundle: true,
  logLevel: "info",
  target: "es2017",
  outdir: "../priv/static/assets",
  external: ["*.css", "images/*"],
  nodePaths: ["../deps"],
  loader: loader,
  plugins: plugins,
};

if (deploy) {
  const phxHost = process.env.PHX_HOST;

  if (!phxHost ) {
    throw new Error("PHX_HOST must be provided")
  }

  opts = {
    ...opts,
    minify: true,
    define: {
      'process.env.PHX_MODE': '"production"',
      // TODO remove
      'process.env.PHX_BASE_HTTP_URL': `"https://${phxHost}/api"`,
      'process.env.PHX_BASE_WS_URL': `"wss://${phxHost}/socket"`,
    },
  };
}

if (watch) {
  opts = {
    ...opts,
    sourcemap: "inline",
    define: {
      'process.env.PHX_MODE': '"development"',
      // TODO remove
      'process.env.PHX_BASE_HTTP_URL': '"http://localhost:4000/socket"',
      'process.env.PHX_BASE_WS_URL': '"ws://localhost:4000/socket"',
    },
  };
  esbuild
    .context(opts)
    .then((ctx) => {
      ctx.watch();
    })
    .catch((_error) => {
      process.exit(1);
    });
} else {
  esbuild.build(opts);
}
