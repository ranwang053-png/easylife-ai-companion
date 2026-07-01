import type { JsonObject, MemoryExtractResponse } from "../types.js";

export interface MemoryExtractionProvider {
  extract(input: JsonObject): Promise<MemoryExtractResponse>;
}
