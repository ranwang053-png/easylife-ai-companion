import { createApp } from "./app.js";
import { loadConfig } from "./config.js";

const config = loadConfig();
const app = createApp({ config });

const server = app.listen(config.port, config.host, () => {
  if (config.logLevel !== "silent") {
    console.info(
      JSON.stringify({
        event: "server_started",
        host: config.host,
        port: config.port,
      }),
    );
  }
});

function shutdown(signal: string): void {
  if (config.logLevel !== "silent") {
    console.info(JSON.stringify({ event: "server_stopping", signal }));
  }

  server.close((error) => {
    if (error !== undefined) {
      process.exitCode = 1;
    }
  });
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
