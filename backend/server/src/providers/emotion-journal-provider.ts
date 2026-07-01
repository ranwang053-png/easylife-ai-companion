import type { EmotionJournalSummaryResponse, JsonObject } from "../types.js";

export interface EmotionJournalProvider {
  summarize(input: JsonObject): Promise<EmotionJournalSummaryResponse>;
}
