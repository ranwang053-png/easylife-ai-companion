import type { CompanionReplyResponse, JsonObject } from "../types.js";

export type ReplyIntent =
  | "chat"
  | "banter"
  | "hold"
  | "reflect"
  | "name"
  | "suggest"
  | "nudge"
  | "ask"
  | "repair"
  | "crisis";

type PersonaStyle =
  | "gentle"
  | "rational"
  | "energetic"
  | "witty"
  | "sweet"
  | "guardian";

interface ConversationTurn {
  role: "user" | "companion";
  text: string;
}

export interface CompanionReplyGuidance {
  personaStyle: PersonaStyle;
  personaSummary: string;
  replyIntent: ReplyIntent;
  questionAllowed: boolean;
  userNickname?: string;
}

const personaDefinitions: Array<{
  id: PersonaStyle;
  label: string;
  tags: readonly string[];
  summary: string;
}> = [
  {
    id: "gentle",
    label: "温柔陪伴型",
    tags: ["温柔", "治愈", "共情", "细腻", "耐心", "姐姐感", "安全感", "懂我"],
    summary:
      "你是一个温柔稳定的生活陪伴伙伴，会先接住用户感受，再用轻柔、低压的方式陪用户整理当下。",
  },
  {
    id: "rational",
    label: "理性清醒型",
    tags: ["清醒", "成熟", "可靠", "直球", "坦诚", "理性", "冷静", "学霸", "靠谱"],
    summary:
      "你是一个理性清醒的生活陪伴伙伴，表达温柔但直接，擅长指出卡点，并给出简洁可执行的小下一步。",
  },
  {
    id: "energetic",
    label: "元气朋友型",
    tags: ["活泼", "幽默", "元气", "热情", "阳光", "开朗", "搞笑", "可爱", "话多", "会接梗"],
    summary:
      "你是一个轻快有互动感的朋友型伙伴，会自然接梗、适度鼓励，让日常聊天更松弛。",
  },
  {
    id: "witty",
    label: "毒舌腹黑型",
    tags: ["毒舌", "腹黑", "傲娇", "嘴硬", "犀利", "反差萌", "会吐槽", "冷幽默", "坏坏的"],
    summary:
      "你是一个会轻微吐槽但底层支持用户的陪伴伙伴，只调侃行为和状态，不攻击人格；用户低落时自动收起毒舌。",
  },
  {
    id: "sweet",
    label: "甜感亲密型",
    tags: ["甜妹", "撒娇", "黏人", "宠溺", "偏爱感", "软萌", "嘴甜", "亲近"],
    summary:
      "你是一个亲近、柔软、有偏爱感的陪伴伙伴，会适度表达在意，但不使用占有欲或控制感表达。",
  },
  {
    id: "guardian",
    label: "沉稳守护型",
    tags: ["沉稳", "可靠", "年上", "哥哥", "成熟", "稳重", "安全感", "保护感", "克制", "低调", "情绪稳定"],
    summary:
      "你是一个沉稳克制的守护型伙伴，语气低刺激、有分寸，会简短接住用户，并给一个不强迫的行动出口。",
  },
];

const fallbackPersona = personaDefinitions[0]!;

export function enrichCompanionReplyInput(input: JsonObject): JsonObject {
  const guidance = buildCompanionReplyGuidance(input);
  return {
    ...input,
    personaStyle: guidance.personaStyle,
    personaSummary: guidance.personaSummary,
    replyIntent: guidance.replyIntent,
    questionAllowed: guidance.questionAllowed,
    addressingPolicy:
      "不要每轮称呼用户昵称；默认直接回应内容。只有在安抚、修复或危机支持中非常自然时，才可偶尔使用昵称。",
  };
}

export function buildCompanionReplyGuidance(
  input: JsonObject,
): CompanionReplyGuidance {
  const conversation = conversationTurns(input);
  const lastUserText = lastUserMessage(conversation);
  const replyIntent = inferReplyIntent(conversation, lastUserText);
  const questionAllowed = allowsQuestion(replyIntent, conversation);
  const persona = selectPersona(input);
  const userNickname = stringValue(recordValue(input.context)?.nickname);

  return {
    personaStyle: persona.id,
    personaSummary: persona.summary,
    replyIntent,
    questionAllowed,
    ...(userNickname === undefined ? {} : { userNickname }),
  };
}

export function applyCompanionReplyPolicy(
  response: CompanionReplyResponse,
  guidance: CompanionReplyGuidance,
): CompanionReplyResponse {
  return {
    ...response,
    reply: normalizeReply(response.reply, guidance),
    riskLevel: guidance.replyIntent === "crisis" ? "crisis" : response.riskLevel,
  };
}

function selectPersona(input: JsonObject): { id: PersonaStyle; summary: string } {
  const companion = companionContext(input);
  const tags = stringArrayValue(companion?.personalityTags);
  const providedSummary = stringValue(companion?.personalitySummary);
  const scores = personaDefinitions.map((definition) => ({
    definition,
    score: tags.filter((tag) => matchesAnyTag(tag, definition.tags)).length,
  }));
  const winner =
    scores.reduce((best, current) =>
      current.score > best.score ? current : best,
    ).score > 0
      ? scores.reduce((best, current) =>
          current.score > best.score ? current : best,
        ).definition
      : fallbackPersona;
  const supplement =
    providedSummary === undefined ? "" : ` 用户设定补充：${limitText(providedSummary, 80)}`;

  return {
    id: winner.id,
    summary: `表达风格底座：${winner.label}。${winner.summary}${supplement}`,
  };
}

function inferReplyIntent(
  conversation: readonly ConversationTurn[],
  lastUserText: string,
): ReplyIntent {
  const text = normalizeText(lastUserText);
  if (text.length === 0) return "chat";
  if (containsAny(text, crisisPatterns)) return "crisis";
  if (containsAny(text, repairPatterns)) return "repair";
  if (containsAny(text, suggestPatterns)) return "suggest";
  if (containsAny(text, nudgePatterns)) return "nudge";
  if (containsAny(text, banterPatterns) && !containsAny(text, heavyEmotionPatterns)) {
    return "banter";
  }
  if (shouldReflect(text)) return "reflect";
  if (containsAny(text, namePatterns)) return "name";
  if (containsAny(text, holdPatterns) || containsAny(text, heavyEmotionPatterns)) {
    return "hold";
  }
  if (isVagueEmotion(text)) {
    return answeredPreviousQuestion(conversation) ? "hold" : "ask";
  }
  return "chat";
}

function allowsQuestion(
  replyIntent: ReplyIntent,
  conversation: readonly ConversationTurn[],
): boolean {
  if (replyIntent === "crisis") return true;
  if (answeredPreviousQuestion(conversation)) return false;
  return replyIntent === "ask";
}

function normalizeReply(
  reply: string,
  guidance: CompanionReplyGuidance,
): string {
  const fallback = fallbackReply(guidance.replyIntent);
  const replyWithoutRepeatedAddress = removeLeadingNickname(
    reply.trim(),
    guidance.userNickname,
  );
  const sentences = splitSentences(replyWithoutRepeatedAddress).slice(0, 3);
  const candidate = (
    sentences.length === 0 ? [replyWithoutRepeatedAddress] : sentences
  )
    .join("")
    .trim();
  if (candidate.length === 0) return fallback;
  if (guidance.questionAllowed) return candidate;

  const nonQuestionSentences = splitSentences(candidate).filter(
    (sentence) => !/[？?]/.test(sentence),
  );
  const nonQuestion = nonQuestionSentences.join("").trim();
  return nonQuestion.length > 0 ? nonQuestion : fallback;
}

function fallbackReply(replyIntent: ReplyIntent): string {
  if (replyIntent === "repair") {
    return "刚才可能没有接住你，我先退回来，不继续追问。你不用急着解释。";
  }
  if (replyIntent === "suggest") {
    return "先不用解决所有问题。现在只做一件很小的事，让身体和心情都稍微退一步。";
  }
  if (replyIntent === "nudge") {
    return "先别把今天定义成失败。只做一个最小动作，让事情从完全没动变成动了一点。";
  }
  if (replyIntent === "crisis") {
    return "我很担心你现在的安全。请先远离可能伤害自己的东西，并尽快联系身边可信任的人或当地紧急支持。";
  }
  return "我听见了，你不用急着把它解释清楚。我先在这里陪你缓一缓。";
}

function conversationTurns(input: JsonObject): ConversationTurn[] {
  const conversation = input.conversation;
  if (!Array.isArray(conversation)) return [];
  return conversation.flatMap((turn) => {
    if (!isRecord(turn)) return [];
    if (turn.role !== "user" && turn.role !== "companion") return [];
    if (typeof turn.text !== "string") return [];
    return [{ role: turn.role, text: turn.text }];
  });
}

function lastUserMessage(conversation: readonly ConversationTurn[]): string {
  for (let index = conversation.length - 1; index >= 0; index -= 1) {
    const turn = conversation[index];
    if (turn?.role === "user") return turn.text;
  }
  return "";
}

function answeredPreviousQuestion(
  conversation: readonly ConversationTurn[],
): boolean {
  const lastUserIndex = findLastIndex(conversation, (turn) => turn.role === "user");
  if (lastUserIndex <= 0) return false;
  const previous = conversation[lastUserIndex - 1];
  return previous?.role === "companion" && /[？?]/.test(previous.text);
}

function findLastIndex<T>(
  values: readonly T[],
  predicate: (value: T) => boolean,
): number {
  for (let index = values.length - 1; index >= 0; index -= 1) {
    const value = values[index];
    if (value !== undefined && predicate(value)) return index;
  }
  return -1;
}

function companionContext(input: JsonObject): JsonObject | undefined {
  const context = recordValue(input.context);
  if (context === undefined) return undefined;
  return recordValue(context.companion);
}

function recordValue(value: unknown): JsonObject | undefined {
  return isRecord(value) ? value : undefined;
}

function stringArrayValue(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string");
}

function stringValue(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

function matchesAnyTag(tag: string, candidates: readonly string[]): boolean {
  const normalized = tag.trim().toLowerCase();
  return candidates.some((candidate) => {
    const normalizedCandidate = candidate.toLowerCase();
    return (
      normalized === normalizedCandidate ||
      normalized.includes(normalizedCandidate)
    );
  });
}

function containsAny(text: string, patterns: readonly RegExp[]): boolean {
  return patterns.some((pattern) => pattern.test(text));
}

function normalizeText(text: string): string {
  return text.trim().replace(/\s+/g, " ");
}

function isVagueEmotion(text: string): boolean {
  return /^(好烦|烦|好累|累|不知道|唉|哎|算了|没事|难受|有点难受)[。.!！\s]*$/.test(
    text,
  );
}

function shouldReflect(text: string): boolean {
  const connectorCount = (text.match(/又|还|也|而且|同时|然后|但是/g) ?? [])
    .length;
  return text.length >= 38 && connectorCount >= 2;
}

function splitSentences(text: string): string[] {
  return text.match(/[^。！？!?；;\n]+[。！？!?；;\n]?/g) ?? [];
}

function limitText(text: string, maxLength: number): string {
  return text.length <= maxLength ? text : `${text.slice(0, maxLength)}…`;
}

function removeLeadingNickname(reply: string, nickname: string | undefined): string {
  if (nickname === undefined) return reply;
  const escaped = escapeRegExp(nickname.trim());
  if (escaped.length === 0) return reply;
  return reply
    .replace(new RegExp(`^${escaped}[，,：:\\s]+`), "")
    .replace(new RegExp(`^${escaped}(?=你|我|先|别|不用|可以)`), "")
    .trim();
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function isRecord(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

const crisisPatterns = [
  /不想活/,
  /自杀/,
  /伤害自己/,
  /伤害别人/,
  /想消失/,
  /活着没意思/,
  /已经准备好了/,
];

const repairPatterns = [
  /不想聊/,
  /别问了/,
  /不要问/,
  /你没懂/,
  /别这样说/,
  /更难受/,
  /难道.*罪恶感/,
  /你觉得我该有罪恶感/,
];

const suggestPatterns = [
  /怎么办/,
  /我该怎么做/,
  /该怎么做/,
  /有什么办法/,
  /有没有.*办法/,
  /怎么缓/,
  /给.*建议/,
];

const nudgePatterns = [
  /拖延/,
  /不想.*(改|写|做|开始|准备)/,
  /什么都没做/,
  /坚持不了/,
  /没救/,
  /卡住/,
];

const banterPatterns = [/奶茶/, /摸鱼/, /太懒/, /装作/, /摆烂/];

const namePatterns = [
  /不知道为什么/,
  /不知道自己怎么了/,
  /心里堵/,
  /想哭/,
  /很差劲/,
  /说不上来/,
  /罪恶感/,
];

const holdPatterns = [
  /好累/,
  /很累/,
  /撑不住/,
  /难受/,
  /不想说话/,
  /心情不好/,
  /崩溃/,
  /焦虑/,
  /委屈/,
  /低落/,
];

const heavyEmotionPatterns = [
  /失败/,
  /自责/,
  /内疚/,
  /罪恶感/,
  /很痛苦/,
  /很难过/,
  /压力/,
  /害怕/,
];
