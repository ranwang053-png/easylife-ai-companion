import type { Request } from "express";

import type { ErrorCode, JsonObject } from "../types.js";

export interface AuthContext {
  userId: string;
  sessionId: string;
}

export interface AuthService {
  sendSmsCode(body: JsonObject, request: Request): Promise<JsonObject>;
  verifySmsCode(body: JsonObject, request: Request): Promise<JsonObject>;
  refreshTokens(body: JsonObject): Promise<JsonObject>;
  authenticateAccessToken(
    token: string,
    options?: { allowRevoked?: boolean },
  ): Promise<AuthContext | null>;
  logout(context: AuthContext, body: JsonObject): Promise<void>;
  deleteAccount(context: AuthContext, body: JsonObject): Promise<JsonObject>;
}

export class AuthServiceError extends Error {
  constructor(readonly code: ErrorCode) {
    super(code);
    this.name = "AuthServiceError";
  }
}
