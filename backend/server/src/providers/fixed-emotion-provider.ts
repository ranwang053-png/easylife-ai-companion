import { contractExample } from "../contract.js";
import type { EmotionAnalyzeResponse, JsonObject } from "../types.js";
import type { EmotionProvider } from "./emotion-provider.js";

export class FixedEmotionProvider implements EmotionProvider {
  async analyze(_input: JsonObject): Promise<EmotionAnalyzeResponse> {
    return contractExample<EmotionAnalyzeResponse>(
      "EmotionAnalyzeResponse",
    );
  }
}
