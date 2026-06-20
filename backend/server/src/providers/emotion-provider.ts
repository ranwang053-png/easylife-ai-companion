import type { EmotionAnalyzeResponse, JsonObject } from "../types.js";

export interface EmotionProvider {
  analyze(input: JsonObject): Promise<EmotionAnalyzeResponse>;
}
