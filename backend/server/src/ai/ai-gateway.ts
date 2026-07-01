import type { AiCapability, AiCapabilityConfig, AiConfig } from "../config.js";
import type { CompanionReplyProvider } from "../providers/companion-reply-provider.js";
import type { EmotionProvider } from "../providers/emotion-provider.js";
import type { EmotionJournalProvider } from "../providers/emotion-journal-provider.js";
import type { MemoryExtractionProvider } from "../providers/memory-extraction-provider.js";
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

  companionReplyProvider(): CompanionReplyProvider {
    return this.registry.companionReplyProvider();
  }

  emotionJournalProvider(): EmotionJournalProvider {
    return this.registry.emotionJournalProvider();
  }

  memoryExtractionProvider(): MemoryExtractionProvider {
    return this.registry.memoryExtractionProvider();
  }

  petAvatarProvider(): PetAvatarProvider {
    return this.registry.petAvatarProvider();
  }
}
