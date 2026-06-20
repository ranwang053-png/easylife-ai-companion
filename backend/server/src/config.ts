export interface AppConfig {
  host: string;
  port: number;
  nodeEnv: string;
  logLevel: "silent" | "info";
  enableTestTriggers: boolean;
  fixedAccessTokens: readonly string[];
}

export function loadConfig(
  environment: NodeJS.ProcessEnv = process.env,
): AppConfig {
  const port = Number.parseInt(environment.PORT ?? "3000", 10);
  const nodeEnv = environment.NODE_ENV ?? "development";
  const fixedAccessToken = environment.FIXED_ACCESS_TOKEN;
  const fixedRotatedAccessToken = environment.FIXED_ROTATED_ACCESS_TOKEN;

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }

  if (
    nodeEnv !== "development" &&
    nodeEnv !== "test" &&
    (fixedAccessToken === undefined ||
      fixedRotatedAccessToken === undefined)
  ) {
    throw new Error(
      "FIXED_ACCESS_TOKEN and FIXED_ROTATED_ACCESS_TOKEN must be configured outside development and test",
    );
  }

  return {
    host: environment.HOST ?? "127.0.0.1",
    port,
    nodeEnv,
    logLevel: environment.LOG_LEVEL === "silent" ? "silent" : "info",
    enableTestTriggers: environment.ENABLE_TEST_TRIGGERS === "true",
    fixedAccessTokens: [
      fixedAccessToken ??
        "example-access-token-with-at-least-twenty-characters",
      fixedRotatedAccessToken ??
        "rotated-access-token-with-at-least-twenty-characters",
    ],
  };
}
