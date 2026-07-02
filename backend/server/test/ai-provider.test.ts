import {
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  createServer,
  type IncomingMessage,
  type ServerResponse,
} from "node:http";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { describe, expect, it } from "vitest";
import { PNG } from "pngjs";

import { createApp } from "../src/app.js";
import { AiGateway } from "../src/ai/ai-gateway.js";
import { loadConfig } from "../src/config.js";
import { contractExample, validateContractSchema } from "../src/contract.js";

const authorization =
  "Bearer example-access-token-with-at-least-twenty-characters";

const emotionResult = {
  label: "疲惫",
  labels: ["疲惫", "压力"],
  intensity: 64,
  possibleReason: "最近任务比较密集，你可能一直在撑着把事情做完。",
  petSuggestion: "先把今晚必须做的事缩到一件，剩下的明天再看。",
  petReply: "听起来你已经努力很久了。我们先不用急着证明什么，慢慢把最累的地方说清楚。",
  petStatus: "担忧",
};

const croppedAvatarPng = pngWithVisibleRect({
  width: 64,
  height: 64,
  left: 0,
  top: 0,
  right: 63,
  bottom: 63,
});
const completeAvatarPng = pngWithVisibleRect({
  width: 64,
  height: 64,
  left: 12,
  top: 10,
  right: 51,
  bottom: 53,
});

describe("AI provider registry", () => {
  it.each([
    ["openai", "OPENAI", "/v1/chat/completions"],
    ["deepseek", "DEEPSEEK", "/v1/chat/completions"],
    ["doubao", "DOUBAO", "/api/v3/chat/completions"],
  ] as const)(
    "routes emotion analysis through %s OpenAI-compatible adapter",
    async (provider, envPrefix, expectedPath) => {
      const captured: Array<{
        authorization: string | undefined;
        path: string | undefined;
        body: unknown;
      }> = [];

      await withJsonServer(async (incoming, response, body) => {
        captured.push({
          authorization: incoming.headers.authorization,
          path: incoming.url,
          body: JSON.parse(body),
        });
        sendJson(response, 200, {
          choices: [
            {
              message: {
                content: JSON.stringify(emotionResult),
              },
            },
          ],
        });
      }, async (baseUrl) => {
        const configuredBaseUrl =
          provider === "doubao" ? `${baseUrl}/api/v3` : `${baseUrl}/v1`;
        const config = loadConfig({
          NODE_ENV: "test",
          AI_PROVIDER: "gateway",
          AI_EMOTION_PROVIDER: provider,
          AI_EMOTION_MODEL: `${provider}-emotion-model`,
          [`${envPrefix}_API_KEY`]: `${provider}-test-key`,
          [`${envPrefix}_BASE_URL`]: configuredBaseUrl,
        });
        const gateway = new AiGateway(config.ai);
        const app = createApp({
          config,
          emotionProvider: gateway.emotionProvider(),
        });

        const providerResponse = await request(app)
          .post("/v1/emotion/analyze")
          .set("Authorization", authorization)
          .send(contractExample("EmotionAnalyzeRequest"));

        expect(providerResponse.status).toBe(200);
        expect(validateContractSchema("EmotionAnalyzeResponse", providerResponse.body))
          .toEqual({ valid: true });
        expect(providerResponse.body).toEqual(emotionResult);
        expect(captured).toHaveLength(1);
        expect(captured[0]?.authorization).toBe(`Bearer ${provider}-test-key`);
        expect(captured[0]?.path).toBe(expectedPath);
        expect(captured[0]?.body).toMatchObject({
          model: `${provider}-emotion-model`,
          response_format: { type: "json_object" },
        });
        const providerBody = captured[0]?.body as {
          messages?: Array<{ content?: string; role?: string }>;
        };
        expect(providerBody.messages?.[0]?.content).toContain(
          "优先回应用户最后一句的具体感受",
        );
        expect(providerBody.messages?.[0]?.content).toContain(
          "input.context.companion",
        );
      });
    },
  );

  it("uses GPT-5 compatible token parameters for OpenAI text models", async () => {
    const captured: Array<{ body: unknown }> = [];

    await withJsonServer(async (_incoming, response, body) => {
      captured.push({ body: JSON.parse(body) });
      sendJson(response, 200, {
        choices: [
          {
            message: {
              content: JSON.stringify(emotionResult),
            },
          },
        ],
      });
    }, async (baseUrl) => {
      const config = loadConfig({
        NODE_ENV: "test",
        AI_PROVIDER: "gateway",
        AI_EMOTION_PROVIDER: "openai",
        AI_EMOTION_MODEL: "gpt-5.5",
        OPENAI_API_KEY: "openai-test-key",
        OPENAI_BASE_URL: `${baseUrl}/v1`,
      });
      const gateway = new AiGateway(config.ai);
      const app = createApp({
        config,
        emotionProvider: gateway.emotionProvider(),
      });

      const providerResponse = await request(app)
        .post("/v1/emotion/analyze")
        .set("Authorization", authorization)
        .send(contractExample("EmotionAnalyzeRequest"));

      expect(providerResponse.status).toBe(200);
    });

    expect(captured).toHaveLength(1);
    const providerBody = captured[0]?.body as Record<string, unknown>;
    expect(providerBody.model).toBe("gpt-5.5");
    expect(providerBody.max_completion_tokens).toBe(1000);
    expect(providerBody).not.toHaveProperty("max_tokens");
    expect(providerBody).not.toHaveProperty("temperature");
  });

  it("uses OPENAI_MODEL and appends /v1 for root OpenAI-compatible base URLs", async () => {
    const captured: Array<{
      path: string | undefined;
      body: unknown;
    }> = [];

    await withJsonServer(async (incoming, response, body) => {
      captured.push({
        path: incoming.url,
        body: JSON.parse(body),
      });
      sendJson(response, 200, {
        choices: [
          {
            message: {
              content: JSON.stringify(emotionResult),
            },
          },
        ],
      });
    }, async (baseUrl) => {
      const config = loadConfig({
        NODE_ENV: "test",
        AI_PROVIDER: "gateway",
        AI_EMOTION_PROVIDER: "openai",
        OPENAI_API_KEY: "openai-test-key",
        OPENAI_BASE_URL: baseUrl,
        OPENAI_MODEL: "aihubmix-test-model",
      });
      const gateway = new AiGateway(config.ai);
      const app = createApp({
        config,
        emotionProvider: gateway.emotionProvider(),
      });

      const providerResponse = await request(app)
        .post("/v1/emotion/analyze")
        .set("Authorization", authorization)
        .send(contractExample("EmotionAnalyzeRequest"));

      expect(providerResponse.status).toBe(200);
    });

    expect(captured).toHaveLength(1);
    expect(captured[0]?.path).toBe("/v1/chat/completions");
    expect(captured[0]?.body).toMatchObject({
      model: "aihubmix-test-model",
    });
  });

  it("routes emotion analysis through the Anthropic adapter", async () => {
    const captured: Array<{
      apiKey: string | string[] | undefined;
      version: string | string[] | undefined;
      path: string | undefined;
      body: unknown;
    }> = [];

    await withJsonServer(async (incoming, response, body) => {
      captured.push({
        apiKey: incoming.headers["x-api-key"],
        version: incoming.headers["anthropic-version"],
        path: incoming.url,
        body: JSON.parse(body),
      });
      sendJson(response, 200, {
        content: [
          {
            type: "text",
            text: `\`\`\`json\n${JSON.stringify(emotionResult)}\n\`\`\``,
          },
        ],
      });
    }, async (baseUrl) => {
      const config = loadConfig({
        NODE_ENV: "test",
        AI_PROVIDER: "gateway",
        AI_EMOTION_PROVIDER: "anthropic",
        AI_EMOTION_MODEL: "claude-test-model",
        ANTHROPIC_API_KEY: "anthropic-test-key",
        ANTHROPIC_BASE_URL: baseUrl,
      });
      const gateway = new AiGateway(config.ai);
      const app = createApp({
        config,
        emotionProvider: gateway.emotionProvider(),
      });

      const providerResponse = await request(app)
        .post("/v1/emotion/analyze")
        .set("Authorization", authorization)
        .send(contractExample("EmotionAnalyzeRequest"));

      expect(providerResponse.status).toBe(200);
      expect(validateContractSchema("EmotionAnalyzeResponse", providerResponse.body))
        .toEqual({ valid: true });
      expect(providerResponse.body).toEqual(emotionResult);
      expect(captured).toHaveLength(1);
      expect(captured[0]?.apiKey).toBe("anthropic-test-key");
      expect(captured[0]?.version).toBe("2023-06-01");
      expect(captured[0]?.path).toBe("/v1/messages");
      expect(captured[0]?.body).toMatchObject({
        model: "claude-test-model",
      });
    });
  });

  it("routes pet avatar generation through the OpenAI image adapter", async () => {
    const captured: Array<{
      authorization: string | undefined;
      contentType: string | undefined;
      path: string | undefined;
      body: string;
    }> = [];

    await withJsonServer(async (incoming, response, body) => {
      captured.push({
        authorization: incoming.headers.authorization,
        contentType: incoming.headers["content-type"],
        path: incoming.url,
        body,
      });
      sendJson(response, 200, {
        data: [
          {
            b64_json:
              "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
          },
        ],
      });
    }, async (baseUrl) => {
      const config = loadConfig({
        NODE_ENV: "test",
        AI_PROVIDER: "gateway",
        AI_PET_AVATAR_PROVIDER: "openai",
        AI_PET_AVATAR_MODEL: "gpt-image-1",
        OPENAI_API_KEY: "openai-test-key",
        OPENAI_BASE_URL: `${baseUrl}/v1`,
      });
      const gateway = new AiGateway(config.ai);
      const app = createApp({
        config,
        petAvatarProvider: gateway.petAvatarProvider(),
      });

      const providerResponse = await request(app)
        .post("/v1/pet-avatar/generate")
        .set("Authorization", authorization)
        .send(contractExample("PetAvatarGenerateRequest"));

      expect(providerResponse.status).toBe(200);
      expect(validateContractSchema("PetAvatarGenerateResponse", providerResponse.body))
        .toEqual({ valid: true });
      expect(providerResponse.body.generatedAvatarUrl).toMatch(
        /^data:image\/png;base64,/,
      );
      expect(captured).toHaveLength(1);
      expect(captured[0]?.authorization).toBe("Bearer openai-test-key");
      expect(captured[0]?.path).toBe("/v1/images/edits");
      expect(captured[0]?.contentType).toContain("multipart/form-data");
      expect(captured[0]?.body).toContain("gpt-image-1");
      expect(captured[0]?.body).toContain(
        "Transform the uploaded subject into a premium full-body cartoon cutout collectible mascot",
      );
      expect(captured[0]?.body).toContain(
        "visible from head to shoes/paws",
      );
      expect(captured[0]?.body).not.toContain("Storage And Privacy");
    });
  });

  it("appends /v1 for root OpenAI-compatible image base URLs", async () => {
    const captured: Array<{ path: string | undefined }> = [];

    await withJsonServer(async (incoming, response) => {
      captured.push({ path: incoming.url });
      sendJson(response, 200, {
        data: [
          {
            b64_json:
              "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
          },
        ],
      });
    }, async (baseUrl) => {
      const config = loadConfig({
        NODE_ENV: "test",
        AI_PROVIDER: "gateway",
        AI_PET_AVATAR_PROVIDER: "openai",
        AI_PET_AVATAR_MODEL: "gpt-image-1",
        OPENAI_API_KEY: "openai-test-key",
        OPENAI_BASE_URL: baseUrl,
      });
      const gateway = new AiGateway(config.ai);
      const app = createApp({
        config,
        petAvatarProvider: gateway.petAvatarProvider(),
      });

      const providerResponse = await request(app)
        .post("/v1/pet-avatar/generate")
        .set("Authorization", authorization)
        .send(contractExample("PetAvatarGenerateRequest"));

      expect(providerResponse.status).toBe(200);
    });

    expect(captured).toHaveLength(1);
    expect(captured[0]?.path).toBe("/v1/images/edits");
  });

  it("passes configured pet avatar style reference images to the image adapter", async () => {
    const styleDir = mkdtempSync(join(tmpdir(), "easylife-style-ref-"));
    writeFileSync(
      join(styleDir, "blind-box-style.png"),
      Buffer.from(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
        "base64",
      ),
    );
    const captured: Array<{ body: string }> = [];

    try {
      await withJsonServer(async (_incoming, response, body) => {
        captured.push({ body });
        sendJson(response, 200, {
          data: [
            {
              b64_json:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
            },
          ],
        });
      }, async (baseUrl) => {
        const config = loadConfig({
          NODE_ENV: "test",
          AI_PROVIDER: "gateway",
          AI_PET_AVATAR_PROVIDER: "openai",
          AI_PET_AVATAR_MODEL: "gpt-image-1",
          AI_PET_AVATAR_STYLE_REFERENCE_DIR: styleDir,
          OPENAI_API_KEY: "openai-test-key",
          OPENAI_BASE_URL: `${baseUrl}/v1`,
        });
        const gateway = new AiGateway(config.ai);
        const app = createApp({
          config,
          petAvatarProvider: gateway.petAvatarProvider(),
        });

        const providerResponse = await request(app)
          .post("/v1/pet-avatar/generate")
          .set("Authorization", authorization)
          .send(contractExample("PetAvatarGenerateRequest"));

        expect(providerResponse.status).toBe(200);
      });

      expect(captured).toHaveLength(1);
      const body = captured[0]?.body ?? "";
      expect(body).not.toContain('name="image"');
      expect(body.match(/name="image\[\]"/g)).toHaveLength(2);
      expect(body).toContain('filename="subject.png"');
      expect(body).toContain('filename="style-reference-blind-box-style.png"');
      expect(body).toContain('name="background"');
      expect(body).toContain("transparent");
      expect(body).toContain('name="output_format"');
      expect(body).toContain("png");
      expect(body).toContain('name="input_fidelity"');
      expect(body).toContain("high");
    } finally {
      rmSync(styleDir, { recursive: true, force: true });
    }
  });

  it("retries pet avatar generation when the first cutout is cropped", async () => {
    const captured: Array<{ body: string }> = [];

    await withJsonServer(async (_incoming, response, body) => {
      captured.push({ body });
      sendJson(response, 200, {
        data: [
          {
            b64_json: captured.length === 1
              ? croppedAvatarPng
              : completeAvatarPng,
          },
        ],
      });
    }, async (baseUrl) => {
      const config = loadConfig({
        NODE_ENV: "test",
        AI_PROVIDER: "gateway",
        AI_PET_AVATAR_PROVIDER: "openai",
        AI_PET_AVATAR_MODEL: "gpt-image-1",
        OPENAI_API_KEY: "openai-test-key",
        OPENAI_BASE_URL: `${baseUrl}/v1`,
      });
      const gateway = new AiGateway(config.ai);
      const app = createApp({
        config,
        petAvatarProvider: gateway.petAvatarProvider(),
      });

      const providerResponse = await request(app)
        .post("/v1/pet-avatar/generate")
        .set("Authorization", authorization)
        .send(contractExample("PetAvatarGenerateRequest"));

      expect(providerResponse.status).toBe(200);
      expect(providerResponse.body.generatedAvatarUrl).toBe(
        `data:image/png;base64,${completeAvatarPng}`,
      );
    });

    expect(captured).toHaveLength(2);
    expect(captured[1]?.body).toContain("previous attempt was cropped");
  });
});

async function withJsonServer(
  handler: (
    request: IncomingMessage,
    response: ServerResponse,
    body: string,
  ) => Promise<void> | void,
  run: (baseUrl: string) => Promise<void>,
): Promise<void> {
  const server = createServer(async (incoming, response) => {
    try {
      const body = await readBody(incoming);
      await handler(incoming, response, body);
    } catch {
      sendJson(response, 500, { error: "test server failed" });
    }
  });
  await new Promise<void>((resolve) => {
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address() as AddressInfo;
  try {
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) reject(error);
        else resolve();
      });
    });
  }
}

function readBody(request: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk: string) => {
      body += chunk;
    });
    request.on("end", () => resolve(body));
    request.on("error", reject);
  });
}

function sendJson(
  response: ServerResponse,
  status: number,
  payload: unknown,
): void {
  response.writeHead(status, { "Content-Type": "application/json" });
  response.end(JSON.stringify(payload));
}

function pngWithVisibleRect(options: {
  width: number;
  height: number;
  left: number;
  top: number;
  right: number;
  bottom: number;
}): string {
  const png = new PNG({ width: options.width, height: options.height });
  for (let y = options.top; y <= options.bottom; y += 1) {
    for (let x = options.left; x <= options.right; x += 1) {
      const index = (options.width * y + x) << 2;
      png.data[index] = 30;
      png.data[index + 1] = 120;
      png.data[index + 2] = 90;
      png.data[index + 3] = 255;
    }
  }
  return PNG.sync.write(png).toString("base64");
}
