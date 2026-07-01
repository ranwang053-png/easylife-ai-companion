import type { EmotionProvider } from "../providers/emotion-provider.js";
import type { EmotionAnalyzeResponse, JsonObject } from "../types.js";
import type { TextModelAdapter } from "./text-model-adapters.js";

const emotionSystemPrompt = `
你是 Easylife 的情绪陪伴分析助手。请根据用户输入，输出给 App 使用的结构化 JSON。

原则：
- 先温柔接住用户情绪，不要诊断，不要说教，不要制造焦虑。
- 可以自然命名情绪，但避免像报告一样评判用户。
- 陪伴回复优先回应用户最后一句的具体感受，少用套话，不要每轮都称呼用户名字。
- 当用户只是模糊表达不舒服、担心、焦虑、烦、难过，但还没有说明具体发生了什么时，优先温和追问“发生了什么/最担心哪件事”，不要急着给解决方案。
- 如果 input.context.companion 提供了伙伴名字、性格标签或性格总结，回复语气要轻微贴合这个伙伴，不要过度角色扮演。
- 不保存数据，不声称已经写入日记。
- 如果用户表达明确自伤或危机信号，petSuggestion 应建议尽快联系可信任的人或当地紧急支持。

只输出合法 JSON，不要输出 Markdown、解释或多余文字。JSON 必须符合：
{
  "label": "一个主情绪标签，2到8个中文字符",
  "labels": ["1到4个情绪标签，第一项与 label 一致"],
  "intensity": 0到100之间的整数,
  "possibleReason": "一句温和的可能背景，不超过100字",
  "petSuggestion": "一个轻量、具体、低压力的小建议，不超过80字；如果当前更适合继续倾听，可以为空字符串，或写一句“慢慢说给我听也可以”这类非任务型陪伴",
  "petReply": "像熟悉朋友一样的自然回复，80到160字，接住用户最新一句；如果用户还没讲清楚具体事件，给出一个温和追问；如果用户已经说明情况，再给一个很小的下一步",
  "petStatus": "伙伴状态，使用 期待/担忧/心疼/陪着你/开心/安静 中最合适的一个"
}
`.trim();

export class TextModelEmotionProvider implements EmotionProvider {
  constructor(
    private readonly adapter: TextModelAdapter,
    private readonly model: string,
  ) {}

  async analyze(input: JsonObject): Promise<EmotionAnalyzeResponse> {
    const result = await this.adapter.completeJson({
      model: this.model,
      systemPrompt: emotionSystemPrompt,
      userPayload: {
        input,
      },
      temperature: 0.55,
      maxTokens: 1000,
    });

    return {
      label: requiredString(result, "label"),
      labels: normalizedLabels(result, requiredString(result, "label")),
      intensity: normalizedIntensity(result.intensity),
      possibleReason: requiredString(result, "possibleReason"),
      petSuggestion: requiredString(result, "petSuggestion"),
      petReply: requiredString(result, "petReply"),
      petStatus: requiredString(result, "petStatus"),
    };
  }
}

function requiredString(value: JsonObject, key: string): string {
  const result = value[key];
  if (typeof result !== "string" || result.trim().length === 0) {
    throw new Error(`AI emotion response is missing ${key}`);
  }
  return result.trim();
}

function normalizedLabels(value: JsonObject, label: string): string[] {
  const raw = value.labels;
  if (!Array.isArray(raw)) return [label];
  const labels = raw
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
  const unique = Array.from(new Set([label, ...labels]));
  return unique.slice(0, 4);
}

function normalizedIntensity(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error("AI emotion response is missing intensity");
  }
  return Math.max(0, Math.min(100, Math.round(value)));
}
