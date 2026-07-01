import type { EmotionJournalProvider } from "../providers/emotion-journal-provider.js";
import type { EmotionJournalSummaryResponse, JsonObject } from "../types.js";
import { loadPrompt } from "./prompt-loader.js";
import type { TextModelAdapter } from "./text-model-adapters.js";

const emotionJournalPrompt = loadPrompt(
  "backend/prompts/emotion_journal_summary.v1.md",
);

export class TextModelEmotionJournalProvider implements EmotionJournalProvider {
  constructor(
    private readonly adapter: TextModelAdapter,
    private readonly model: string,
  ) {}

  async summarize(input: JsonObject): Promise<EmotionJournalSummaryResponse> {
    const result = await this.adapter.completeJson({
      model: this.model,
      systemPrompt: emotionJournalPrompt,
      userPayload: {
        input,
        output_contract:
          "Return only JSON with recap, emotion_tags, trigger, insight, next_actions, closing_words.",
      },
      temperature: 0.35,
      maxTokens: 900,
    });
    return {
      recap: stringValue(result.recap),
      emotionTags: stringArray(result.emotion_tags ?? result.emotionTags),
      trigger: stringValue(result.trigger),
      insight: stringValue(result.insight),
      nextActions: stringArray(result.next_actions ?? result.nextActions),
      closingWords: stringValue(result.closing_words ?? result.closingWords),
    };
  }
}

function stringValue(value: unknown): string {
  if (typeof value === "string") return value;
  throw new Error("Emotion journal output contains a non-string field");
}

function stringArray(value: unknown): string[] {
  if (Array.isArray(value) && value.every((item) => typeof item === "string")) {
    return value;
  }
  throw new Error("Emotion journal output contains a non-string array field");
}
