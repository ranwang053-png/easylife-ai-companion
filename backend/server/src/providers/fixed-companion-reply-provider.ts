import { contractExample } from "../contract.js";
import type { CompanionReplyResponse, JsonObject } from "../types.js";
import type { CompanionReplyProvider } from "./companion-reply-provider.js";

export class FixedCompanionReplyProvider implements CompanionReplyProvider {
  async reply(_input: JsonObject): Promise<CompanionReplyResponse> {
    return contractExample<CompanionReplyResponse>("CompanionReplyResponse");
  }
}
