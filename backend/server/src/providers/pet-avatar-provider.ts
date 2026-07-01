import type { JsonObject } from "../types.js";

export interface PetAvatarGenerateResponse {
  generatedAvatarUrl: string;
}

export interface PetAvatarProvider {
  generate(input: JsonObject): Promise<PetAvatarGenerateResponse>;
}
