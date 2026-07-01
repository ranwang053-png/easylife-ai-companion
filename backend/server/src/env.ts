import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { config as loadDotEnv } from "dotenv";
import { ProxyAgent, setGlobalDispatcher } from "undici";

const envPathCandidates = [
  fileURLToPath(new URL("../.env", import.meta.url)),
  fileURLToPath(new URL("../../.env", import.meta.url)),
];

const envPath = envPathCandidates.find(existsSync);
if (envPath !== undefined) {
  loadDotEnv({ path: envPath });
}

const proxyUrl =
  process.env.HTTPS_PROXY ??
  process.env.HTTP_PROXY ??
  process.env.ALL_PROXY ??
  process.env.https_proxy ??
  process.env.http_proxy ??
  process.env.all_proxy;

if (proxyUrl !== undefined && proxyUrl.length > 0) {
  setGlobalDispatcher(new ProxyAgent(proxyUrl));
}
