import type { AiProviderConfig, AiProviderId } from "../config.js";
import type { JsonObject } from "../types.js";

export interface TextCompletionRequest {
  model: string;
  systemPrompt: string;
  userPayload: JsonObject;
  temperature?: number;
  maxTokens?: number;
}

export interface TextModelAdapter {
  completeJson(request: TextCompletionRequest): Promise<JsonObject>;
}

export function createTextModelAdapter(
  providerId: AiProviderId,
  config: AiProviderConfig,
): TextModelAdapter {
  if (
    providerId === "openai" ||
    providerId === "deepseek" ||
    providerId === "doubao"
  ) {
    return new OpenAiCompatibleTextAdapter(providerId, config);
  }
  if (providerId === "anthropic") {
    return new AnthropicTextAdapter(config);
  }
  throw new Error(`AI provider ${providerId} does not support text completion`);
}

class OpenAiCompatibleTextAdapter implements TextModelAdapter {
  constructor(
    private readonly providerId: "openai" | "deepseek" | "doubao",
    private readonly config: AiProviderConfig,
  ) {}

  async completeJson(request: TextCompletionRequest): Promise<JsonObject> {
    const endpoint = resolveEndpoint(
      baseUrlFor(this.providerId, this.config),
      "chat/completions",
    );
    const response = await postJson(endpoint, {
      Authorization: `Bearer ${requiredApiKey(this.providerId, this.config)}`,
      "Content-Type": "application/json",
    }, openAiCompatibleBody(this.providerId, request));

    const content = readOpenAiContent(response);
    return extractJsonObject(content);
  }
}

class AnthropicTextAdapter implements TextModelAdapter {
  constructor(private readonly config: AiProviderConfig) {}

  async completeJson(request: TextCompletionRequest): Promise<JsonObject> {
    const endpoint = resolveEndpoint(
      baseUrlFor("anthropic", this.config),
      "v1/messages",
    );
    const response = await postJson(endpoint, {
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
      "x-api-key": requiredApiKey("anthropic", this.config),
    }, {
      model: request.model,
      system: request.systemPrompt,
      messages: [
        {
          role: "user",
          content: JSON.stringify(request.userPayload),
        },
      ],
      temperature: request.temperature ?? 0.3,
      max_tokens: request.maxTokens ?? 1200,
    });

    const content = readAnthropicContent(response);
    return extractJsonObject(content);
  }
}

function openAiCompatibleBody(
  providerId: "openai" | "deepseek" | "doubao",
  request: TextCompletionRequest,
): JsonObject {
  const base = {
    model: request.model,
    messages: [
      { role: "system", content: request.systemPrompt },
      {
        role: "user",
        content: JSON.stringify(request.userPayload),
      },
    ],
    response_format: { type: "json_object" },
  };
  if (providerId === "openai" && usesOpenAiReasoningParams(request.model)) {
    return {
      ...base,
      max_completion_tokens: request.maxTokens ?? 1200,
    };
  }
  return {
    ...base,
    temperature: request.temperature ?? 0.3,
    max_tokens: request.maxTokens ?? 1200,
  };
}

function usesOpenAiReasoningParams(model: string): boolean {
  const normalized = model.toLowerCase();
  return (
    /^gpt-5(?:[.-]|$)/.test(normalized) ||
    /^o[134](?:[.-]|$)/.test(normalized)
  );
}

function baseUrlFor(
  providerId: "openai" | "anthropic" | "deepseek" | "doubao",
  config: AiProviderConfig,
): URL {
  if (config.baseUrl !== undefined) return config.baseUrl;
  if (providerId === "openai") return new URL("https://api.openai.com/v1");
  if (providerId === "anthropic") return new URL("https://api.anthropic.com");
  if (providerId === "deepseek") {
    return new URL("https://api.deepseek.com/v1");
  }
  throw new Error("DOUBAO_BASE_URL must be configured when doubao is enabled");
}

function requiredApiKey(
  providerId: AiProviderId,
  config: AiProviderConfig,
): string {
  if (config.apiKey !== undefined) return config.apiKey;
  throw new Error(`AI provider ${providerId} is missing an API key`);
}

function resolveEndpoint(baseUrl: URL, suffix: string): URL {
  const normalizedSuffix = suffix.startsWith("/") ? suffix.slice(1) : suffix;
  const normalizedPath = baseUrl.pathname.replace(/\/+$/, "");
  if (normalizedPath.endsWith(`/${normalizedSuffix}`)) return baseUrl;
  return new URL(
    `${normalizedPath.length === 0 ? "/" : `${normalizedPath}/`}${normalizedSuffix}`,
    baseUrl.origin,
  );
}

async function postJson(
  url: URL,
  headers: Record<string, string>,
  body: JsonObject,
): Promise<JsonObject> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);
  try {
    const response = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`AI provider returned HTTP ${response.status}`);
    }
    const text = await response.text();
    const parsed: unknown = JSON.parse(text);
    if (!isRecord(parsed)) {
      throw new Error("AI provider returned a non-object response");
    }
    return parsed;
  } finally {
    clearTimeout(timeout);
  }
}

function readOpenAiContent(response: JsonObject): string {
  const choices = response.choices;
  if (!Array.isArray(choices)) {
    throw new Error("OpenAI-compatible response is missing choices");
  }
  const first = choices[0];
  if (!isRecord(first) || !isRecord(first.message)) {
    throw new Error("OpenAI-compatible response is missing message content");
  }
  const content = first.message.content;
  if (typeof content !== "string" || content.length === 0) {
    throw new Error("OpenAI-compatible response content is empty");
  }
  return content;
}

function readAnthropicContent(response: JsonObject): string {
  const content = response.content;
  if (!Array.isArray(content)) {
    throw new Error("Anthropic response is missing content");
  }
  const parts = content
    .map((part) => (isRecord(part) && typeof part.text === "string" ? part.text : ""))
    .filter((part) => part.length > 0);
  if (parts.length === 0) {
    throw new Error("Anthropic response content is empty");
  }
  return parts.join("\n");
}

function extractJsonObject(content: string): JsonObject {
  const withoutFence = content
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  const start = withoutFence.indexOf("{");
  const end = withoutFence.lastIndexOf("}");
  if (start < 0 || end < start) {
    throw new Error("AI provider response did not contain a JSON object");
  }
  const parsed: unknown = JSON.parse(withoutFence.slice(start, end + 1));
  if (!isRecord(parsed)) {
    throw new Error("AI provider JSON response is not an object");
  }
  return parsed;
}

function isRecord(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
