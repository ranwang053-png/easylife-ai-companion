export type JsonObject = Record<string, unknown>;

export interface ErrorBody {
  error: {
    code: ErrorCode;
    message: string;
    requestId: string;
  };
}

export type ErrorCode =
  | "VALIDATION_ERROR"
  | "UNAUTHORIZED"
  | "PAYLOAD_TOO_LARGE"
  | "SMS_CODE_EXPIRED"
  | "SMS_CODE_INVALID"
  | "VERIFICATION_ATTEMPTS_EXCEEDED"
  | "SMS_PROVIDER_UNAVAILABLE"
  | "INVALID_REFRESH_TOKEN"
  | "INVALID_SYNC_CURSOR"
  | "DELETION_VERIFICATION_EXPIRED"
  | "AI_OUTPUT_INVALID"
  | "RATE_LIMITED"
  | "AI_PROVIDER_UNAVAILABLE";

export interface EmotionAnalyzeResponse {
  label: string;
  labels: string[];
  intensity: number;
  possibleReason: string;
  petSuggestion: string;
  petReply: string;
  petStatus: string;
}

export interface CompanionReplyResponse {
  reply: string;
  emotionLabel: string | null;
  riskLevel: "none" | "concern" | "crisis";
  serviceSuggestion:
    "breathing" | "emotion_card" | "save_journal" | "self_care" | null;
}

export interface EmotionJournalSummaryResponse {
  recap: string;
  emotionTags: string[];
  trigger: string;
  insight: string;
  nextActions: string[];
  closingWords: string;
}

export interface MemoryExtractResponse {
  memoryCandidates: Array<{
    type:
      | "emotional_sensitivity"
      | "coping_strategy"
      | "current_focus"
      | "communication_preference"
      | "lifestyle_habit"
      | "health_context"
      | "work_study_context"
      | "boundary";
    content: string;
    usage: "companion" | "diet" | "fortune" | "profile";
  }>;
}

export interface PetAvatarGenerateResponse {
  generatedAvatarUrl: string;
}

declare global {
  namespace Express {
    interface Request {
      requestId: string;
      auth?: import("./auth/auth-service.js").AuthContext;
    }
  }
}
