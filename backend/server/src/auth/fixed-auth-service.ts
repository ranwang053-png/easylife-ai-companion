import type { Request } from "express";

import { contractExample } from "../contract.js";
import type { JsonObject } from "../types.js";
import type { AppConfig } from "../config.js";
import type { AuthContext, AuthService } from "./auth-service.js";

const fixedContext: AuthContext = {
  userId: "2b7ed6df-e1dc-4fde-9128-0cb8c4682f85",
  sessionId: "6d10bda5-a10d-43dc-baba-718bc36b74b4",
};

export class FixedAuthService implements AuthService {
  constructor(private readonly config: AppConfig) {}

  async sendSmsCode(_body: JsonObject, _request: Request): Promise<JsonObject> {
    return contractExample<JsonObject>("SendSmsCodeResponse");
  }

  async verifySmsCode(
    _body: JsonObject,
    request: Request,
  ): Promise<JsonObject> {
    if (
      this.config.enableTestTriggers &&
      request.header("X-Easylife-Test-Sms-Purpose") === "account_deletion"
    ) {
      return {
        purpose: "account_deletion",
        deletionToken: "example-deletion-token-with-at-least-twenty-characters",
        expiresIn: 600,
      };
    }
    return contractExample<JsonObject>("LoginVerificationResponse");
  }

  async refreshTokens(_body: JsonObject): Promise<JsonObject> {
    return {
      accessToken: "rotated-access-token-with-at-least-twenty-characters",
      accessTokenExpiresIn: 900,
      refreshToken: "rotated-refresh-token-with-at-least-twenty-characters",
      refreshTokenExpiresIn: 2592000,
    };
  }

  async authenticateAccessToken(token: string): Promise<AuthContext | null> {
    return this.config.fixedAccessTokens.includes(token) ? fixedContext : null;
  }

  async logout(_context: AuthContext, _body: JsonObject): Promise<void> {}

  async deleteAccount(
    _context: AuthContext,
    _body: JsonObject,
  ): Promise<JsonObject> {
    return contractExample<JsonObject>("DeleteAccountResponse");
  }
}
