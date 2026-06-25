import {
  createServer,
  type IncomingMessage,
  type ServerResponse,
} from "node:http";
import { afterEach, describe, expect, it } from "vitest";

import {
  SmsProviderError,
  WebhookSmsProvider,
} from "../src/auth/sms-provider.js";

const servers: ReturnType<typeof createServer>[] = [];

afterEach(async () => {
  await Promise.all(
    servers
      .splice(0)
      .map(
        (server) =>
          new Promise<void>((resolve) => server.close(() => resolve())),
      ),
  );
});

describe("WebhookSmsProvider", () => {
  it("retries retryable failures with one idempotency key", async () => {
    const requests: string[] = [];
    let attempt = 0;
    const endpoint = await listen((request, response) => {
      requests.push(String(request.headers["idempotency-key"]));
      attempt += 1;
      if (attempt === 1) {
        response.statusCode = 503;
        response.end();
        return;
      }
      response.setHeader("content-type", "application/json");
      response.end(JSON.stringify({ messageId: "provider-message-1" }));
    });
    const provider = new WebhookSmsProvider(endpoint, "provider-token", 2);

    await expect(
      provider.sendCode({
        phone: "+8613812345678",
        code: "123456",
        purpose: "login",
        requestId: "6f2aa37d-e95d-4b52-8df4-0cf3e17e5188",
        idempotencyKey: "984e6346-f8a1-4511-8ec2-a960bc338705",
      }),
    ).resolves.toEqual({ messageId: "provider-message-1" });
    expect(requests).toEqual([
      "984e6346-f8a1-4511-8ec2-a960bc338705",
      "984e6346-f8a1-4511-8ec2-a960bc338705",
    ]);
  });

  it("does not retry a non-retryable provider rejection", async () => {
    let attempts = 0;
    const endpoint = await listen((_request, response) => {
      attempts += 1;
      response.statusCode = 400;
      response.end();
    });
    const provider = new WebhookSmsProvider(endpoint, "provider-token", 3);

    await expect(
      provider.sendCode({
        phone: "+8613812345678",
        code: "123456",
        purpose: "login",
        requestId: "6f2aa37d-e95d-4b52-8df4-0cf3e17e5188",
        idempotencyKey: "984e6346-f8a1-4511-8ec2-a960bc338705",
      }),
    ).rejects.toBeInstanceOf(SmsProviderError);
    expect(attempts).toBe(1);
  });
});

async function listen(
  handler: (request: IncomingMessage, response: ServerResponse) => void,
): Promise<URL> {
  const server = createServer(handler);
  servers.push(server);
  await new Promise<void>((resolve) => {
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  if (address === null || typeof address === "string") {
    throw new Error("SMS provider test server did not start");
  }
  return new URL(`http://127.0.0.1:${address.port}/send`);
}
