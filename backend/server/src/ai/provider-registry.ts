import type {
  AiCapability,
  AiCapabilityConfig,
  AiConfig,
  AiProviderConfig,
  AiProviderId,
} from "../config.js";
import { FixedCompanionReplyProvider } from "../providers/fixed-companion-reply-provider.js";
import { FixedEmotionProvider } from "../providers/fixed-emotion-provider.js";
import { FixedEmotionJournalProvider } from "../providers/fixed-emotion-journal-provider.js";
import { FixedMemoryExtractionProvider } from "../providers/fixed-memory-extraction-provider.js";
import { FixedPetAvatarProvider } from "../providers/fixed-pet-avatar-provider.js";
import type { CompanionReplyProvider } from "../providers/companion-reply-provider.js";
import type { EmotionProvider } from "../providers/emotion-provider.js";
import type { EmotionJournalProvider } from "../providers/emotion-journal-provider.js";
import type { MemoryExtractionProvider } from "../providers/memory-extraction-provider.js";
import type { PetAvatarProvider } from "../providers/pet-avatar-provider.js";
import { TextModelCompanionReplyProvider } from "./companion-reply-provider-adapter.js";
import { TextModelEmotionProvider } from "./emotion-provider-adapter.js";
import { TextModelEmotionJournalProvider } from "./emotion-journal-provider-adapter.js";
import { TextModelMemoryExtractionProvider } from "./memory-extraction-provider-adapter.js";
import { OpenAiPetAvatarProvider } from "./pet-avatar-provider-adapter.js";
import { createTextModelAdapter } from "./text-model-adapters.js";

export interface AiProviderRegistry {
  readonly mode: AiConfig["mode"];
  capability(capability: AiCapability): AiCapabilityConfig;
  provider(provider: AiProviderId): AiProviderConfig;
  companionReplyProvider(): CompanionReplyProvider;
  emotionProvider(): EmotionProvider;
  emotionJournalProvider(): EmotionJournalProvider;
  memoryExtractionProvider(): MemoryExtractionProvider;
  petAvatarProvider(): PetAvatarProvider;
}

export function createAiProviderRegistry(
  config: AiConfig | undefined,
): AiProviderRegistry {
  return new ConfiguredAiProviderRegistry(config ?? defaultAiConfig());
}

class ConfiguredAiProviderRegistry implements AiProviderRegistry {
  constructor(private readonly config: AiConfig) {}

  get mode(): AiConfig["mode"] {
    return this.config.mode;
  }

  capability(capability: AiCapability): AiCapabilityConfig {
    return this.config.capabilities[capability];
  }

  provider(provider: AiProviderId): AiProviderConfig {
    return this.config.providers[provider];
  }

  companionReplyProvider(): CompanionReplyProvider {
    if (this.config.mode === "fixed") return new FixedCompanionReplyProvider();
    const route = this.capability("companion");
    if (route.provider === "fixed") return new FixedCompanionReplyProvider();
    const adapter = createTextModelAdapter(
      route.provider,
      this.provider(route.provider),
    );
    return new TextModelCompanionReplyProvider(adapter, route.model);
  }

  emotionProvider(): EmotionProvider {
    if (this.config.mode === "fixed") return new FixedEmotionProvider();
    const route = this.capability("emotion");
    if (route.provider === "fixed") return new FixedEmotionProvider();
    const adapter = createTextModelAdapter(
      route.provider,
      this.provider(route.provider),
    );
    return new TextModelEmotionProvider(adapter, route.model);
  }

  emotionJournalProvider(): EmotionJournalProvider {
    if (this.config.mode === "fixed") return new FixedEmotionJournalProvider();
    const route = this.capability("emotionJournal");
    if (route.provider === "fixed") return new FixedEmotionJournalProvider();
    const adapter = createTextModelAdapter(
      route.provider,
      this.provider(route.provider),
    );
    return new TextModelEmotionJournalProvider(adapter, route.model);
  }

  memoryExtractionProvider(): MemoryExtractionProvider {
    if (this.config.mode === "fixed") return new FixedMemoryExtractionProvider();
    const route = this.capability("memory");
    if (route.provider === "fixed") return new FixedMemoryExtractionProvider();
    const adapter = createTextModelAdapter(
      route.provider,
      this.provider(route.provider),
    );
    return new TextModelMemoryExtractionProvider(adapter, route.model);
  }

  petAvatarProvider(): PetAvatarProvider {
    if (this.config.mode === "fixed") return new FixedPetAvatarProvider();
    const route = this.capability("petAvatar");
    if (route.provider === "fixed") return new FixedPetAvatarProvider();
    if (route.provider !== "openai") {
      throw new Error("Pet avatar generation currently requires openai");
    }
    return new OpenAiPetAvatarProvider(
      this.config.petAvatarProvider ?? this.provider(route.provider),
      route.model,
      this.config.petAvatarStyleReferenceDir,
    );
  }
}

function defaultAiConfig(): AiConfig {
  return {
    mode: "fixed",
    capabilities: {
      companion: { provider: "fixed", model: "fixed" },
      emotion: { provider: "fixed", model: "fixed" },
      emotionJournal: { provider: "fixed", model: "fixed" },
      memory: { provider: "fixed", model: "fixed" },
      petProfile: { provider: "fixed", model: "fixed" },
      dailyFortune: { provider: "fixed", model: "fixed" },
      petAvatar: { provider: "fixed", model: "fixed" },
      dietText: { provider: "fixed", model: "fixed" },
      dietVision: { provider: "fixed", model: "fixed" },
      dietSearch: { provider: "fixed", model: "fixed" },
      foodSegmentation: {
        provider: "fixed",
        model: "fixed",
        imageEnhancement: "none",
      },
    },
    providers: {
      fixed: {},
      openai: {},
      anthropic: {},
      deepseek: {},
      doubao: {},
      birefnet: {},
    },
    petAvatarProvider: {},
  };
}
