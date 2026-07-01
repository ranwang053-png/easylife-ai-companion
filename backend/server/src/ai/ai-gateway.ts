import type { AiCapability, AiCapabilityConfig, AiConfig } from "../config.js";
import type { EmotionProvider } from "../providers/emotion-provider.js";
import type { PetAvatarProvider } from "../providers/pet-avatar-provider.js";
import {
  createAiProviderRegistry,
  type AiProviderRegistry,
} from "./provider-registry.js";

export class AiGateway {
  private readonly registry: AiProviderRegistry;

  constructor(config: AiConfig | undefined) {
    this.registry = createAiProviderRegistry(config);
  }

  capability(capability: AiCapability): AiCapabilityConfig {
    return this.registry.capability(capability);
  }

  emotionProvider(): EmotionProvider {
    return this.registry.emotionProvider();
  }

  petAvatarProvider(): PetAvatarProvider {
    return this.registry.petAvatarProvider();
  }
}
