import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export function loadPrompt(relativePromptPath: string): string {
  const candidates = [
    fileURLToPath(new URL(`../../../${relativePromptPath}`, import.meta.url)),
    fileURLToPath(new URL(`../../../../${relativePromptPath}`, import.meta.url)),
    resolve(process.cwd(), relativePromptPath),
    resolve(process.cwd(), "../../", relativePromptPath),
  ];
  const promptPath = candidates.find(existsSync);
  if (promptPath === undefined) {
    throw new Error(`Unable to locate ${relativePromptPath}`);
  }
  return readFileSync(promptPath, "utf8");
}
