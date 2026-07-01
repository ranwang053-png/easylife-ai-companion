import { contractExample } from "../contract.js";
import type { EmotionJournalSummaryResponse, JsonObject } from "../types.js";
import type { EmotionJournalProvider } from "./emotion-journal-provider.js";

export class FixedEmotionJournalProvider implements EmotionJournalProvider {
  async summarize(_input: JsonObject): Promise<EmotionJournalSummaryResponse> {
    return contractExample<EmotionJournalSummaryResponse>(
      "EmotionJournalSummaryResponse",
    );
  }
}
