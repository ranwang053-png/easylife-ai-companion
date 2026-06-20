# Easylife Prompt Library

This directory stores versioned prompt templates for backend AI providers.

Rules:

- Prompts are backend assets. Do not embed API keys or provider secrets here.
- Do not put complete user private text, phone numbers, tokens, or full profile examples in prompt files.
- Keep each prompt versioned with a stable filename, for example `pet_avatar_generation.v1.md`.
- Provider-specific adapters may transform these templates, but product intent and safety rules should stay traceable here.
- If a prompt changes model output shape, update the API contract and examples before implementation.

