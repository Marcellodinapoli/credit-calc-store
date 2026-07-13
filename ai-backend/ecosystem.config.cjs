/** Configurazione PM2 per il proxy Realtime. */
module.exports = {
  apps: [
    {
      name: "credit-realtime-proxy",
      script: "server.js",
      cwd: __dirname,
      instances: 1,
      autorestart: true,
      max_memory_restart: "512M",
      env: {
        NODE_ENV: "production",
      },
    },
  ],
};
