import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import request from "supertest";
import { describe, expect, it } from "vitest";
import YAML from "yaml";

import { createApp } from "../src/app.js";
import { loadConfig, type AppConfig } from "../src/config.js";
import { contractExample, validateContractSchema } from "../src/contract.js";
import type { EmotionProvider } from "../src/providers/emotion-provider.js";

const requestId = "6f2aa37d-e95d-4b52-8df4-0cf3e17e5188";
const authorization =
  "Bearer example-access-token-with-at-least-twenty-characters";
const contractPath = fileURLToPath(
  new URL("../../../contracts/openapi.yaml", import.meta.url),
);
const openApi = YAML.parse(readFileSync(contractPath, "utf8")) as {
  info: { version: string };
  paths: Record<string, unknown>;
};

const config: AppConfig = {
  host: "127.0.0.1",
  port: 3000,
  nodeEnv: "test",
  logLevel: "silent",
  allowedOrigins: [],
  enableTestTriggers: true,
  fixedAccessTokens: [
    "example-access-token-with-at-least-twenty-characters",
    "rotated-access-token-with-at-least-twenty-characters",
  ],
  portfolioDemoAccessTokens: [],
};
const app = createApp({ config });

function expectSchema(schemaName: string, value: unknown): void {
  const validation = validateContractSchema(schemaName, value);
  expect(validation).toEqual({ valid: true });
}

function expectError(
  response: request.Response,
  status: number,
  code: string,
): void {
  expect(response.status).toBe(status);
  expect(response.headers["x-request-id"]).toBe(requestId);
  expect(response.body.error.code).toBe(code);
  expectSchema("ErrorResponse", response.body);
}

describe("OpenAPI V1.1.0 fixed backend", () => {
  it("implements every contracted path", () => {
    expect(openApi.info.version).toBe("1.1.0");
    expect(Object.keys(openApi.paths).sort()).toEqual(
      [
        "/v1/auth/logout",
        "/v1/auth/sms/codes",
        "/v1/auth/sms/verify",
        "/v1/auth/token/refresh",
        "/v1/companion/reply",
        "/v1/emotion/analyze",
        "/v1/emotion-journals/summarize",
        "/v1/me/account",
        "/v1/memories/extract",
        "/v1/pet-avatar/generate",
        "/v1/sync/pull",
        "/v1/sync/push",
      ].sort(),
    );
  });

  it("requires database-backed authentication in production", () => {
    expect(() =>
      loadConfig({
        NODE_ENV: "production",
        PORT: "3000",
      }),
    ).toThrow(/DATABASE_URL/);

    const secrets = Array.from({ length: 8 }, (_, index) =>
      Buffer.alloc(32, index + 1).toString("base64"),
    );
    const production = loadConfig({
      NODE_ENV: "production",
      PORT: "3000",
      DATABASE_URL: "postgresql://localhost/easylife",
      SMS_PROVIDER_URL: "https://sms.example.test/send",
      SMS_PROVIDER_TOKEN: "secret-provider-token",
      PHONE_LOOKUP_PEPPER: secrets[0],
      PHONE_ENCRYPTION_KEY: secrets[1],
      SMS_CODE_PEPPER: secrets[2],
      DEVICE_PEPPER: secrets[3],
      IP_PEPPER: secrets[4],
      REFRESH_TOKEN_PEPPER: secrets[5],
      DELETION_TOKEN_PEPPER: secrets[6],
      ACCESS_TOKEN_KEY: secrets[7],
      ACCOUNT_DELETION_ALLOW_DATABASE_ONLY: "true",
    });

    expect(production.auth?.databaseUrl).toBe(
      "postgresql://localhost/easylife",
    );
  });

  it("allows configured public web origins for browser requests", async () => {
    const publicOrigin = "https://ranwang053-png.github.io";
    const publicApp = createApp({
      config: {
        ...config,
        allowedOrigins: [publicOrigin],
      },
    });

    const response = await request(publicApp)
      .options("/v1/companion/reply")
      .set("Origin", publicOrigin)
      .set("Access-Control-Request-Method", "POST")
      .set("Access-Control-Request-Headers", "Authorization, Content-Type");

    expect(response.status).toBe(204);
    expect(response.headers["access-control-allow-origin"]).toBe(publicOrigin);
    expect(response.headers["vary"]).toBe("Origin");
  });

  it("accepts the configured portfolio demo token for protected AI routes", async () => {
    const demoApp = createApp({
      config: {
        ...config,
        fixedAccessTokens: [],
        portfolioDemoAccessTokens: [
          "example-access-token-with-at-least-twenty-characters",
        ],
      },
    });

    const response = await request(demoApp)
      .post("/v1/companion/reply")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("CompanionReplyRequest"));

    expect(response.status).toBe(200);
    expectSchema("CompanionReplyResponse", response.body);
  });

  it("rejects unknown tokens when only portfolio demo auth is configured", async () => {
    const demoApp = createApp({
      config: {
        ...config,
        fixedAccessTokens: [],
        portfolioDemoAccessTokens: [
          "example-access-token-with-at-least-twenty-characters",
        ],
      },
    });

    const response = await request(demoApp)
      .post("/v1/companion/reply")
      .set("X-Request-Id", requestId)
      .set(
        "Authorization",
        "Bearer unknown-access-token-with-at-least-twenty-characters",
      )
      .send(contractExample("CompanionReplyRequest"));

    expectError(response, 401, "UNAUTHORIZED");
  });

  it("returns the fixed SMS challenge", async () => {
    const response = await request(app)
      .post("/v1/auth/sms/codes")
      .set("X-Request-Id", requestId)
      .send({
        phone: "+8613812345678",
        purpose: "login",
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
      });

    expect(response.status).toBe(200);
    expect(response.headers["x-request-id"]).toBe(requestId);
    expectSchema("SendSmsCodeResponse", response.body);
    expect(response.body).toEqual(contractExample("SendSmsCodeResponse"));
  });

  it("auto-registers and logs in after fixed SMS verification", async () => {
    const response = await request(app)
      .post("/v1/auth/sms/verify")
      .set("X-Request-Id", requestId)
      .send({
        challengeId: "984e6346-f8a1-4511-8ec2-a960bc338705",
        phone: "+8613812345678",
        code: "123456",
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
      });

    expect(response.status).toBe(200);
    expect(response.body.isNewUser).toBe(true);
    expectSchema("LoginVerificationResponse", response.body);
    expect(response.body).toEqual(contractExample("LoginVerificationResponse"));
  });

  it("refreshes tokens and logs out", async () => {
    const refreshResponse = await request(app)
      .post("/v1/auth/token/refresh")
      .set("X-Request-Id", requestId)
      .send({
        refreshToken: "example-refresh-token-with-at-least-twenty-characters",
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
      });
    expect(refreshResponse.status).toBe(200);
    expectSchema("TokenPair", refreshResponse.body);

    const logoutResponse = await request(app)
      .post("/v1/auth/logout")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send({
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
      });
    expect(logoutResponse.status).toBe(204);
  });

  it("returns the fixed emotion result without saving data", async () => {
    const response = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send({
        text: "今天工作很多，我有点累，也担心做得不够好。",
        context: {
          nickname: "小满",
          goals: ["规律作息"],
          personalTags: ["工作压力较高"],
          memoryNotes: ["疲惫、压力：连续加班后很累"],
          petReminderStyle: "轻提醒",
        },
        client: {
          platform: "ios",
          appVersion: "0.3.0+3",
          locale: "zh-CN",
        },
      });

    expect(response.status).toBe(200);
    expectSchema("EmotionAnalyzeResponse", response.body);
    expect(response.body).toEqual(contractExample("EmotionAnalyzeResponse"));
  });

  it("returns the fixed companion reply without saving data", async () => {
    const response = await request(app)
      .post("/v1/companion/reply")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("CompanionReplyRequest"));

    expect(response.status).toBe(200);
    expectSchema("CompanionReplyResponse", response.body);
    expect(response.body).toEqual(contractExample("CompanionReplyResponse"));
  });

  it("returns a fixed emotion journal summary without saving data", async () => {
    const response = await request(app)
      .post("/v1/emotion-journals/summarize")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("EmotionJournalSummaryRequest"));

    expect(response.status).toBe(200);
    expectSchema("EmotionJournalSummaryResponse", response.body);
    expect(response.body).toEqual(
      contractExample("EmotionJournalSummaryResponse"),
    );
  });

  it("returns fixed long-term memory candidates without mutating data", async () => {
    const response = await request(app)
      .post("/v1/memories/extract")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("MemoryExtractRequest"));

    expect(response.status).toBe(200);
    expectSchema("MemoryExtractResponse", response.body);
    expect(response.body).toEqual(contractExample("MemoryExtractResponse"));
  });

  it("returns a fixed pet avatar data URL", async () => {
    const response = await request(app)
      .post("/v1/pet-avatar/generate")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("PetAvatarGenerateRequest"));

    expect(response.status).toBe(200);
    expectSchema("PetAvatarGenerateResponse", response.body);
    expect(response.body).toEqual(contractExample("PetAvatarGenerateResponse"));
  });

  it("returns fixed sync push and pull responses", async () => {
    const pushResponse = await request(app)
      .post("/v1/sync/push")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send({
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
        mutations: [
          {
            mutationId: "4e2576f0-2dae-445f-8f7c-bccec87b97b4",
            entityType: "emotionEntry",
            entityId: "1466e202-579e-47e3-833f-051e1cc591b1",
            operation: "upsert",
            baseVersion: 0,
            clientUpdatedAt: "2026-06-15T08:00:00Z",
            payload: {
              occurredAt: "2026-06-15T08:00:00Z",
              userText: "今天工作很多，我有点累。",
              emotionLabel: "疲惫",
              emotionLabels: ["疲惫", "压力"],
              emotionScore: 0.72,
              petReply: "听起来你已经撑了很久，我们先慢一点。",
              suggestion: "先缩减今晚必须完成的任务。",
            },
          },
          {
            mutationId: "9862cd17-8160-4be5-bd19-d3e73014d970",
            entityType: "memoryNote",
            entityId: "15f4a054-b480-45d8-b9f3-32151f8818b2",
            operation: "upsert",
            baseVersion: 0,
            clientUpdatedAt: "2026-06-15T08:00:00Z",
            payload: {
              content: "疲惫、压力：连续工作后很累",
              sourceEmotionEntryId: "1466e202-579e-47e3-833f-051e1cc591b1",
            },
          },
        ],
      });
    expect(pushResponse.status).toBe(200);
    expectSchema("SyncPushResponse", pushResponse.body);
    expect(pushResponse.body).toEqual(contractExample("SyncPushResponse"));

    const pullResponse = await request(app)
      .get("/v1/sync/pull")
      .query({ limit: 100 })
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization);
    expect(pullResponse.status).toBe(200);
    expectSchema("SyncPullResponse", pullResponse.body);
    expect(pullResponse.body).toEqual(contractExample("SyncPullResponse"));
  });

  it("starts account deletion with the contract response", async () => {
    const response = await request(app)
      .delete("/v1/me/account")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send({
        deletionToken: "example-deletion-token-with-at-least-twenty-characters",
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
      });

    expect(response.status).toBe(202);
    expectSchema("DeleteAccountResponse", response.body);
    expect(response.body).toEqual(contractExample("DeleteAccountResponse"));
  });

  it("rejects invalid request bodies using the standard error body", async () => {
    const response = await request(app)
      .post("/v1/auth/sms/codes")
      .set("X-Request-Id", requestId)
      .send({ phone: "+86123" });

    expectError(response, 400, "VALIDATION_ERROR");
  });

  it("requires bearer auth for protected endpoints", async () => {
    const response = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .send({});

    expectError(response, 401, "UNAUTHORIZED");
  });

  it("rejects an unknown bearer token", async () => {
    const response = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", "Bearer attacker-controlled-token")
      .send(contractExample("EmotionAnalyzeRequest"));

    expectError(response, 401, "UNAUTHORIZED");
  });

  it.each([
    ["/v1/auth/sms/codes", "RATE_LIMITED", 429],
    ["/v1/auth/sms/codes", "SMS_PROVIDER_UNAVAILABLE", 503],
    ["/v1/auth/sms/verify", "SMS_CODE_EXPIRED", 410],
    ["/v1/auth/sms/verify", "SMS_CODE_INVALID", 422],
    ["/v1/auth/sms/verify", "VERIFICATION_ATTEMPTS_EXCEEDED", 429],
  ])("simulates %s %s", async (path, code, status) => {
    const response = await request(app)
      .post(path)
      .set("X-Request-Id", requestId)
      .set("X-Easylife-Test-Error", code)
      .send({});

    expectError(response, status, code);
  });

  it.each([
    ["AI_OUTPUT_INVALID", 422],
    ["PAYLOAD_TOO_LARGE", 413],
    ["RATE_LIMITED", 429],
    ["AI_PROVIDER_UNAVAILABLE", 503],
  ])("simulates emotion error %s", async (code, status) => {
    const response = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .set("X-Easylife-Test-Error", code)
      .send({});

    expectError(response, status, code);
  });

  it("rejects output that violates the emotion response contract", async () => {
    const invalidProvider: EmotionProvider = {
      async analyze() {
        return {
          label: "疲惫",
          labels: ["压力"],
          intensity: 101,
          possibleReason: "",
          petSuggestion: "",
          petReply: "",
          petStatus: "",
        };
      },
    };
    const invalidOutputApp = createApp({
      config,
      emotionProvider: invalidProvider,
    });

    const response = await request(invalidOutputApp)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("EmotionAnalyzeRequest"));

    expectError(response, 422, "AI_OUTPUT_INVALID");
  });

  it("maps provider failures to a safe availability error", async () => {
    const unavailableProvider: EmotionProvider = {
      async analyze() {
        throw new Error("provider response must never reach the client");
      },
    };
    const unavailableApp = createApp({
      config,
      emotionProvider: unavailableProvider,
    });

    const response = await request(unavailableApp)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .send(contractExample("EmotionAnalyzeRequest"));

    expectError(response, 503, "AI_PROVIDER_UNAVAILABLE");
    expect(JSON.stringify(response.body)).not.toContain("provider response");
  });

  it("simulates invalid refresh, cursor, and deletion verification", async () => {
    const refreshResponse = await request(app)
      .post("/v1/auth/token/refresh")
      .set("X-Request-Id", requestId)
      .set("X-Easylife-Test-Error", "INVALID_REFRESH_TOKEN")
      .send({});
    expectError(refreshResponse, 401, "INVALID_REFRESH_TOKEN");

    const pullResponse = await request(app)
      .get("/v1/sync/pull")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .set("X-Easylife-Test-Error", "INVALID_SYNC_CURSOR");
    expectError(pullResponse, 400, "INVALID_SYNC_CURSOR");

    const deleteResponse = await request(app)
      .delete("/v1/me/account")
      .set("X-Request-Id", requestId)
      .set("Authorization", authorization)
      .set("X-Easylife-Test-Error", "DELETION_VERIFICATION_EXPIRED")
      .send({});
    expectError(deleteResponse, 410, "DELETION_VERIFICATION_EXPIRED");
  });

  it("ignores test trigger headers when they are disabled", async () => {
    const productionApp = createApp({
      config: { ...config, enableTestTriggers: false },
    });
    const response = await request(productionApp)
      .post("/v1/auth/sms/codes")
      .set("X-Request-Id", requestId)
      .set("X-Easylife-Test-Error", "RATE_LIMITED")
      .send({
        phone: "+8613812345678",
        purpose: "login",
        deviceId: "6ecb2ba5-6c51-4a40-b908-8be4311c7f85",
      });

    expect(response.status).toBe(200);
    expectSchema("SendSmsCodeResponse", response.body);
  });
});
