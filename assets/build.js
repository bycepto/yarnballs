const esbuild = require("esbuild");
const ElmPlugin = require('esbuild-plugin-elm');

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const deploy = args.includes('--deploy');
const devPort = Number(process.env.STATIC_PORT || "3000");

const loader = {
  '.ico': 'file',
  '.png': 'file'
};

const plugins = [
  ElmPlugin({
    debug: !deploy && watch,
    optimize: deploy,
  }),
];

let opts = {
  assetNames: "[name]",
  entryPoints: ["js/app.js", "css/app.css", "images/*"],
  inject: ["js/websocket.js"],
  bundle: true,
  logLevel: "info",
  target: "es2017",
  outdir: "../cmd/server/static/assets",
  external: ["*.css", "images/*"],
  loader: loader,
  plugins: plugins,
};

if (deploy) {
  const appHost = process.env.APP_HOST;
  const appScheme = process.env.APP_SCHEME || "https";
  const wsScheme = appScheme === "https" ? "wss" : "ws";

  if (!appHost ) {
    throw new Error("APP_HOST must be provided")
  }

  opts = {
    ...opts,
    minify: true,
    define: {
      'process.env.APP_MODE': '"production"',
      'process.env.BASE_HTTP_URL': `"${appScheme}://${appHost}"`,
      'process.env.BASE_WS_URL': `"${wsScheme}://${appHost}/ws"`,
    },
  };
}

if (watch) {
  opts = {
    ...opts,
    sourcemap: "inline",
    define: {
      'process.env.APP_MODE': '"development"',
      'process.env.BASE_HTTP_URL': '"http://localhost:8080"',
      'process.env.BASE_WS_URL': '"ws://localhost:8080/ws"',
    },
  };
  esbuild
    .context(opts)
    .then((ctx) => {
      ctx.watch();
      ctx.serve({ port: devPort, servedir: "../cmd/server/static" });
    })
    .catch((_error) => {
      process.exit(1);
    });
} else {
  esbuild.build(opts);
}
