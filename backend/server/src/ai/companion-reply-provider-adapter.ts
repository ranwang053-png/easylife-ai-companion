import type { CompanionReplyProvider } from "../providers/companion-reply-provider.js";
import type { CompanionReplyResponse, JsonObject } from "../types.js";
import { loadPrompt } from "./prompt-loader.js";
import type { TextModelAdapter } from "./text-model-adapters.js";

const companionReplyPrompt = loadPrompt("backend/prompts/companion_reply.v1.md");

export class TextModelCompanionReplyProvider implements CompanionReplyProvider {
  constructor(
    private readonly adapter: TextModelAdapter,
    private readonly model: string,
  ) {}

  async reply(input: JsonObject): Promise<CompanionReplyResponse> {
    const result = await this.adapter.completeJson({
      model: this.model,
      systemPrompt: companionReplyPrompt,
      userPayload: {
        input,
        output_contract:
          "Return only JSON with reply, emotionLabel, riskLevel, serviceSuggestion.",
      },
      temperature: 0.45,
      maxTokens: 700,
    });
    return {
      reply: stringValue(result.reply),
      emotionLabel: nullableString(result.emotionLabel),
      riskLevel: riskLevelValue(result.riskLevel),
      serviceSuggestion: serviceSuggestionValue(result.serviceSuggestion),
    };
  }
}

function stringValue(value: unknown): string {
  if (typeof value === "string") return value;
  throw new Error("Companion reply output contains a non-string field");
}

function nullableString(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string") return value;
  throw new Error("Companion reply output contains an invalid emotionLabel");
}

function riskLevelValue(value: unknown): CompanionReplyResponse["riskLevel"] {
  if (value === "none" || value === "concern" || value === "crisis") {
    return value;
  }
  throw new Error("Companion reply output contains an invalid riskLevel");
}

function serviceSuggestionValue(
  value: unknown,
): CompanionReplyResponse["serviceSuggestion"] {
  if (
    value === null ||
    value === undefined ||
    value === "breathing" ||
    value === "emotion_card" ||
    value === "save_journal" ||
    value === "self_care"
  ) {
    return value ?? null;
  }
  throw new Error("Companion reply output contains an invalid serviceSuggestion");
}
