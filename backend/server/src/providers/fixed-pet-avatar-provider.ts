import type {
  PetAvatarGenerateResponse,
  PetAvatarProvider,
} from "./pet-avatar-provider.js";

const transparentPixelPng =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=";

export class FixedPetAvatarProvider implements PetAvatarProvider {
  async generate(): Promise<PetAvatarGenerateResponse> {
    return {
      generatedAvatarUrl: `data:image/png;base64,${transparentPixelPng}`,
    };
  }
}
