import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { isAbsolute, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PNG } from "pngjs";

import type { AiProviderConfig } from "../config.js";
import type {
  PetAvatarGenerateResponse,
  PetAvatarProvider,
} from "../providers/pet-avatar-provider.js";
import type { JsonObject } from "../types.js";

const promptPathCandidates = [
  fileURLToPath(
    new URL("../../../prompts/pet_avatar_generation.v1.md", import.meta.url),
  ),
  fileURLToPath(
    new URL("../../../../prompts/pet_avatar_generation.v1.md", import.meta.url),
  ),
];

const promptPath = promptPathCandidates.find(existsSync);
const petAvatarPrompt =
  promptPath === undefined
    ? "Transform the uploaded subject into a refined premium 3D collectible mascot for Easylife."
    : extractProductionPrompt(readFileSync(promptPath, "utf8"));

export class OpenAiPetAvatarProvider implements PetAvatarProvider {
  constructor(
    private readonly config: AiProviderConfig,
    private readonly model: string,
    private readonly styleReferenceDir?: string,
  ) {}

  async generate(input: JsonObject): Promise<PetAvatarGenerateResponse> {
    const imageDataUrl = requiredString(input, "imageDataUrl");
    const subjectDescription = optionalString(input, "subjectDescription");
    const image = parseImageDataUrl(imageDataUrl);
    const endpoint = resolveEndpoint(baseUrlFor(this.config), "images/edits");
    const styleReferences = loadStyleReferenceImages(this.styleReferenceDir);
    const basePrompt = buildPrompt(subjectDescription);
    let lastImage: string | undefined;

    for (let attempt = 0; attempt < 3; attempt += 1) {
      const b64Json = await this.generateOnce({
        endpoint,
        image,
        styleReferences,
        prompt: attempt === 0
          ? basePrompt
          : `${basePrompt}\n\nThe previous attempt was cropped or too close to the canvas edge. Regenerate a complete full-body transparent cutout with the entire head, hair/ears/hat, body, legs, and shoes/paws fully visible, with at least 12% transparent padding on all sides.`,
      });
      lastImage = b64Json;
      if (!isCroppedCutout(b64Json)) {
        return {
          generatedAvatarUrl: `data:image/png;base64,${b64Json}`,
        };
      }
    }

    if (lastImage !== undefined) {
      return {
        generatedAvatarUrl: `data:image/png;base64,${lastImage}`,
      };
    }
    throw new Error("Image provider response is missing b64_json");
  }

  private async generateOnce(options: {
    endpoint: URL;
    image: {
      bytes: ArrayBuffer;
      fileName: string;
      mimeType: string;
    };
    styleReferences: Array<{
      bytes: ArrayBuffer;
      fileName: string;
      mimeType: string;
    }>;
    prompt: string;
  }): Promise<string> {
    const form = new FormData();
    form.set("model", this.model);
    form.set("prompt", options.prompt);
    form.set("size", "1024x1024");
    form.set("quality", "medium");
    form.set("background", "transparent");
    form.set("output_format", "png");
    form.set("input_fidelity", "high");
    const imageFieldName =
      options.styleReferences.length === 0 ? "image" : "image[]";
    form.append(
      imageFieldName,
      new Blob([options.image.bytes], { type: options.image.mimeType }),
      options.image.fileName,
    );
    for (const reference of options.styleReferences) {
      form.append(
        imageFieldName,
        new Blob([reference.bytes], { type: reference.mimeType }),
        reference.fileName,
      );
    }

    const response = await fetchWithTimeout(options.endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${requiredApiKey(this.config)}`,
      },
      body: form,
    });
    const parsed = await response.json();
    if (!isRecord(parsed)) {
      throw new Error("Image provider returned a non-object response");
    }
    return readImageB64(parsed);
  }
}

function buildPrompt(subjectDescription: string | undefined): string {
  if (subjectDescription === undefined) return petAvatarPrompt;
  return `${petAvatarPrompt}\n\nSubject description from user:\n${subjectDescription}`;
}

function extractProductionPrompt(markdown: string): string {
  const match = /## Production Prompt\s+([\s\S]*?)(?:\n## |\s*$)/.exec(
    markdown,
  );
  return (match?.[1] ?? markdown).trim();
}

function parseImageDataUrl(value: string): {
  bytes: ArrayBuffer;
  fileName: string;
  mimeType: string;
} {
  const match = /^data:(image\/(?:png|jpe?g|webp));base64,([a-z0-9+/=\s]+)$/i.exec(
    value,
  );
  if (match === null) {
    throw new Error("Pet avatar input must be a PNG, JPEG or WebP data URL");
  }
  const rawMimeType = match[1];
  const rawBase64 = match[2];
  if (rawMimeType === undefined || rawBase64 === undefined) {
    throw new Error("Pet avatar input data URL is invalid");
  }
  const mimeType = rawMimeType.toLowerCase().replace("image/jpg", "image/jpeg");
  const bytes = Buffer.from(rawBase64.replace(/\s/g, ""), "base64");
  if (bytes.length === 0 || bytes.length > 8 * 1024 * 1024) {
    throw new Error("Pet avatar image size is invalid");
  }
  const extension = mimeType === "image/png"
    ? "png"
    : mimeType === "image/webp"
      ? "webp"
      : "jpg";
  return {
    bytes: bytes.buffer.slice(
      bytes.byteOffset,
      bytes.byteOffset + bytes.byteLength,
    ),
    fileName: `subject.${extension}`,
    mimeType,
  };
}

function loadStyleReferenceImages(
  configuredDir: string | undefined,
): Array<{
  bytes: ArrayBuffer;
  fileName: string;
  mimeType: string;
}> {
  const directory = resolveStyleReferenceDir(configuredDir);
  if (!existsSync(directory)) return [];

  const images: Array<{
    bytes: ArrayBuffer;
    fileName: string;
    mimeType: string;
  }> = [];
  for (const name of readdirSync(directory)
    .filter((candidate) => !candidate.startsWith("."))
    .sort((left, right) => left.localeCompare(right))) {
    const path = join(directory, name);
    const metadata = statSync(path);
    if (!metadata.isFile()) continue;
    const mimeType = mimeTypeForFileName(name);
    if (mimeType === undefined) continue;
    if (metadata.size <= 0 || metadata.size > 8 * 1024 * 1024) {
      throw new Error(`Pet avatar style reference is too large: ${name}`);
    }
    images.push({
      bytes: arrayBufferFromBuffer(readFileSync(path)),
      fileName: `style-reference-${name}`,
      mimeType,
    });
    if (images.length >= 3) break;
  }
  return images;
}

function arrayBufferFromBuffer(buffer: Buffer): ArrayBuffer {
  return new Uint8Array(buffer).buffer;
}

function resolveStyleReferenceDir(configuredDir: string | undefined): string {
  const defaultDir = fileURLToPath(
    new URL("../../../style-references/pet-avatar", import.meta.url),
  );
  if (configuredDir === undefined || configuredDir.trim().length === 0) {
    return defaultDir;
  }
  const trimmed = configuredDir.trim();
  return isAbsolute(trimmed) ? trimmed : join(process.cwd(), trimmed);
}

function mimeTypeForFileName(name: string): string | undefined {
  const lowerName = name.toLowerCase();
  if (lowerName.endsWith(".png")) return "image/png";
  if (lowerName.endsWith(".jpg") || lowerName.endsWith(".jpeg")) {
    return "image/jpeg";
  }
  if (lowerName.endsWith(".webp")) return "image/webp";
  return undefined;
}

function readImageB64(response: JsonObject): string {
  const data = response.data;
  if (!Array.isArray(data) || data.length === 0) {
    throw new Error("Image provider response is missing data");
  }
  const first = data[0];
  if (!isRecord(first) || typeof first.b64_json !== "string") {
    throw new Error("Image provider response is missing b64_json");
  }
  return first.b64_json;
}

function isCroppedCutout(b64Json: string): boolean {
  try {
    const png = PNG.sync.read(Buffer.from(b64Json, "base64"));
    const bounds = visibleAlphaBounds(png);
    if (bounds === undefined) return true;
    const horizontalMargin = Math.round(png.width * 0.08);
    const verticalMargin = Math.round(png.height * 0.08);
    return (
      bounds.left < horizontalMargin ||
      bounds.top < verticalMargin ||
      png.width - 1 - bounds.right < horizontalMargin ||
      png.height - 1 - bounds.bottom < verticalMargin
    );
  } catch {
    return false;
  }
}

function visibleAlphaBounds(png: PNG): {
  left: number;
  top: number;
  right: number;
  bottom: number;
} | undefined {
  let left = png.width;
  let top = png.height;
  let right = -1;
  let bottom = -1;
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const alpha = png.data[(png.width * y + x) * 4 + 3];
      if (alpha === undefined || alpha < 16) continue;
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }
  if (right < left || bottom < top) return undefined;
  return { left, top, right, bottom };
}

function baseUrlFor(config: AiProviderConfig): URL {
  if (config.baseUrl !== undefined) return config.baseUrl;
  return new URL("https://api.openai.com/v1");
}

function requiredApiKey(config: AiProviderConfig): string {
  if (config.apiKey !== undefined) return config.apiKey;
  throw new Error("AI provider openai is missing an API key");
}

function requiredString(value: JsonObject, key: string): string {
  const result = value[key];
  if (typeof result !== "string" || result.trim().length === 0) {
    throw new Error(`Pet avatar request is missing ${key}`);
  }
  return result.trim();
}

function optionalString(value: JsonObject, key: string): string | undefined {
  const result = value[key];
  if (typeof result !== "string" || result.trim().length === 0) {
    return undefined;
  }
  return result.trim().slice(0, 300);
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

async function fetchWithTimeout(
  url: URL,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 90_000);
  try {
    const response = await fetch(url, {
      ...init,
      signal: controller.signal,
    });
    if (!response.ok) {
      const body = await response.text().catch(() => "");
      throw new Error(
        `Image provider returned HTTP ${response.status}${
          body.length === 0 ? "" : `: ${body.slice(0, 500)}`
        }`,
      );
    }
    return response;
  } finally {
    clearTimeout(timeout);
  }
}

function isRecord(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
