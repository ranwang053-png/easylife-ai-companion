import type { MemoryExtractionProvider } from "../providers/memory-extraction-provider.js";
import type { JsonObject, MemoryExtractResponse } from "../types.js";
import { loadPrompt } from "./prompt-loader.js";
import type { TextModelAdapter } from "./text-model-adapters.js";

const memoryPrompt = loadPrompt(
  "backend/prompts/long_term_memory_extraction.v1.md",
);

export class TextModelMemoryExtractionProvider
  implements MemoryExtractionProvider
{
  constructor(
    private readonly adapter: TextModelAdapter,
    private readonly model: string,
  ) {}

  async extract(input: JsonObject): Promise<MemoryExtractResponse> {
    const result = await this.adapter.completeJson({
      model: this.model,
      systemPrompt: memoryPrompt,
      userPayload: {
        input,
        output_contract:
          "Return only JSON with memory_candidates array. Do not include confidence.",
      },
      temperature: 0.2,
      maxTokens: 600,
    });
    const rawCandidates = result.memory_candidates ?? result.memoryCandidates;
    if (!Array.isArray(rawCandidates)) {
      throw new Error("Memory extraction output is missing memory candidates");
    }
    return {
      memoryCandidates: rawCandidates.map((candidate) =>
        memoryCandidate(candidate),
      ),
    };
  }
}

function memoryCandidate(value: unknown): MemoryExtractResponse["memoryCandidates"][number] {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Memory candidate is not an object");
  }
  const record = value as Record<string, unknown>;
  return {
    type: memoryType(record.type),
    content: stringValue(record.content),
    usage: memoryUsage(record.usage),
  };
}

function stringValue(value: unknown): string {
  if (typeof value === "string") return value;
  throw new Error("Memory candidate contains a non-string content field");
}

function memoryType(
  value: unknown,
): MemoryExtractResponse["memoryCandidates"][number]["type"] {
  if (
    value === "preference" ||
    value === "pattern" ||
    value === "goal" ||
    value === "boundary" ||
    value === "context"
  ) {
    return value;
  }
  throw new Error("Memory candidate contains an invalid type");
}

function memoryUsage(
  value: unknown,
): MemoryExtractResponse["memoryCandidates"][number]["usage"] {
  if (
    value === "companion" ||
    value === "diet" ||
    value === "fortune" ||
    value === "profile"
  ) {
    return value;
  }
  throw new Error("Memory candidate contains an invalid usage");
}
