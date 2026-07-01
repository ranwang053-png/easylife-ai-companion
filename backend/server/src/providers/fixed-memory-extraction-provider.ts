import { contractExample } from "../contract.js";
import type { JsonObject, MemoryExtractResponse } from "../types.js";
import type { MemoryExtractionProvider } from "./memory-extraction-provider.js";

export class FixedMemoryExtractionProvider implements MemoryExtractionProvider {
  async extract(_input: JsonObject): Promise<MemoryExtractResponse> {
    return contractExample<MemoryExtractResponse>("MemoryExtractResponse");
  }
}
