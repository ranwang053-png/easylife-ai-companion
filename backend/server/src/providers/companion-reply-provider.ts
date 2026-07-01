import type { CompanionReplyResponse, JsonObject } from "../types.js";

export interface CompanionReplyProvider {
  reply(input: JsonObject): Promise<CompanionReplyResponse>;
}
