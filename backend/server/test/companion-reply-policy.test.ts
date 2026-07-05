import { describe, expect, it } from "vitest";

import {
  applyCompanionReplyPolicy,
  buildCompanionReplyGuidance,
} from "../src/ai/companion-reply-policy.js";
import { TextModelCompanionReplyProvider } from "../src/ai/companion-reply-provider-adapter.js";
import type {
  TextCompletionRequest,
  TextModelAdapter,
} from "../src/ai/text-model-adapters.js";
import type { JsonObject } from "../src/types.js";

describe("companion reply policy", () => {
  it("maps companion personality tags to a persona summary", () => {
    const guidance = buildCompanionReplyGuidance(
      companionRequest({
        lastUserText: "我今天有点卡住。",
        personalityTags: ["理性", "靠谱"],
      }),
    );

    expect(guidance.personaStyle).toBe("rational");
    expect(guidance.personaSummary).toContain("表达风格底座：理性清醒型");
    expect(guidance.personaSummary).toContain("简洁可执行");
  });

  it("does not ask again when the user just answered a companion question", () => {
    const guidance = buildCompanionReplyGuidance({
      conversation: [
        { role: "user", text: "我周末睡到下午，感觉有点罪恶感。" },
        { role: "companion", text: "这种休息对你来说更像放松，还是有点罪恶感？" },
        { role: "user", text: "有点罪恶感，觉得自己浪费了时间。" },
      ],
      context: companionContext(["温柔"]),
      client: clientContext(),
    });

    expect(guidance.replyIntent).toBe("name");
    expect(guidance.questionAllowed).toBe(false);
    expect(
      applyCompanionReplyPolicy(
        {
          reply: "这更像是一点自责和罪恶感。你想继续说说它从哪来的吗？",
          emotionLabel: "自责",
          riskLevel: "none",
          serviceSuggestion: null,
        },
        guidance,
      ).reply,
    ).not.toMatch(/[？?]/);
  });

  it("holds clear feelings instead of ending with a question", () => {
    const guidance = buildCompanionReplyGuidance(
      companionRequest({ lastUserText: "我今天真的好累，什么都不想说。" }),
    );

    expect(guidance.replyIntent).toBe("hold");
    expect(guidance.questionAllowed).toBe(false);
    expect(
      applyCompanionReplyPolicy(
        {
          reply: "听起来你真的耗得很厉害。是身体累，还是心里也累？",
          emotionLabel: "疲惫",
          riskLevel: "none",
          serviceSuggestion: null,
        },
        guidance,
      ).reply,
    ).toBe("听起来你真的耗得很厉害。");
  });

  it("suggests one small step when the user asks what to do", () => {
    const guidance = buildCompanionReplyGuidance(
      companionRequest({ lastUserText: "那我现在该怎么办？" }),
    );

    expect(guidance.replyIntent).toBe("suggest");
    expect(guidance.questionAllowed).toBe(false);
  });

  it("repairs or holds when the user resists being questioned", () => {
    for (const lastUserText of [
      "不想聊了，别问了。",
      "难道你觉得我应该有罪恶感吗？",
    ]) {
      const guidance = buildCompanionReplyGuidance(
        companionRequest({ lastUserText }),
      );

      expect(guidance.replyIntent).toBe("repair");
      expect(guidance.questionAllowed).toBe(false);
    }
  });

  it("enriches the companion prompt payload without an extra model call", async () => {
    const adapter = new CapturingTextAdapter({
      reply: "先别把今天定义成失败。现在只做一个最小动作，打开文件就好。",
      emotionLabel: "卡住",
      riskLevel: "none",
      serviceSuggestion: null,
    });
    const provider = new TextModelCompanionReplyProvider(adapter, "test-model");

    const result = await provider.reply(
      companionRequest({
        lastUserText: "我又拖延了，感觉自己没救了。",
        personalityTags: ["沉稳", "可靠"],
      }),
    );

    expect(result.reply).toBe(
      "先别把今天定义成失败。现在只做一个最小动作，打开文件就好。",
    );
    expect(adapter.requests).toHaveLength(1);
    const payload = adapter.requests[0]?.userPayload.input as JsonObject;
    expect(payload.replyIntent).toBe("nudge");
    expect(payload.questionAllowed).toBe(false);
    expect(payload.personaSummary).toContain("表达风格底座：沉稳守护型");
    expect(payload.addressingPolicy).toContain("不要每轮称呼用户昵称");
  });

  it("removes repeated leading user nickname from model replies", async () => {
    const guidance = buildCompanionReplyGuidance(
      companionRequest({ lastUserText: "我今天很累。" }),
    );

    const result = applyCompanionReplyPolicy(
      {
        reply: "小满，你今天已经撑了很久。先不用急着解释清楚。",
        emotionLabel: "疲惫",
        riskLevel: "none",
        serviceSuggestion: null,
      },
      guidance,
    );

    expect(result.reply).toBe("你今天已经撑了很久。先不用急着解释清楚。");
  });

  it("keeps a slightly longer three-sentence reply when useful", () => {
    const guidance = buildCompanionReplyGuidance(
      companionRequest({ lastUserText: "今天体重又涨了，我有点烦。" }),
    );

    const result = applyCompanionReplyPolicy(
      {
        reply:
          "看到数字上涨确实会烦。一天的体重不等于这段时间的努力。很多时候只是水分、盐分和作息在波动。",
        emotionLabel: "烦躁",
        riskLevel: "none",
        serviceSuggestion: null,
      },
      guidance,
    );

    expect(result.reply).toBe(
      "看到数字上涨确实会烦。一天的体重不等于这段时间的努力。很多时候只是水分、盐分和作息在波动。",
    );
  });
});

class CapturingTextAdapter implements TextModelAdapter {
  readonly requests: TextCompletionRequest[] = [];

  constructor(private readonly response: JsonObject) {}

  async completeJson(request: TextCompletionRequest): Promise<JsonObject> {
    this.requests.push(request);
    return this.response;
  }
}

function companionRequest({
  lastUserText,
  personalityTags = ["温柔"],
}: {
  lastUserText: string;
  personalityTags?: string[];
}): JsonObject {
  return {
    conversation: [{ role: "user", text: lastUserText }],
    context: companionContext(personalityTags),
    client: clientContext(),
  };
}

function companionContext(personalityTags: string[]): JsonObject {
  return {
    nickname: "小满",
    goals: ["规律作息"],
    personalTags: ["工作压力较高"],
    memoryNotes: ["低落时更希望先被倾听"],
    petReminderStyle: "轻提醒",
    companion: {
      name: "一团",
      personalityTags,
      relationshipNote: "我的陪伴伙伴",
      personalitySummary: "会在用户忙过头时轻轻提醒休息。",
    },
  };
}

function clientContext(): JsonObject {
  return {
    platform: "ios",
    appVersion: "0.3.0+3",
    locale: "zh-CN",
  };
}
