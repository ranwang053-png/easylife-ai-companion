import type { Request } from "express";

import type { JsonObject } from "../types.js";
import type { AuthContext, AuthService } from "./auth-service.js";

const portfolioDemoContext: AuthContext = {
  userId: "portfolio-demo-user",
  sessionId: "portfolio-demo-session",
};

export class PortfolioDemoAuthService implements AuthService {
  constructor(
    private readonly delegate: AuthService,
    private readonly accessTokens: readonly string[],
  ) {}

  sendSmsCode(body: JsonObject, request: Request): Promise<JsonObject> {
    return this.delegate.sendSmsCode(body, request);
  }

  verifySmsCode(body: JsonObject, request: Request): Promise<JsonObject> {
    return this.delegate.verifySmsCode(body, request);
  }

  refreshTokens(body: JsonObject): Promise<JsonObject> {
    return this.delegate.refreshTokens(body);
  }

  async authenticateAccessToken(
    token: string,
    options?: { allowRevoked?: boolean },
  ): Promise<AuthContext | null> {
    const context = await this.delegate.authenticateAccessToken(token, options);
    if (context !== null) {
      return context;
    }

    return this.accessTokens.includes(token) ? portfolioDemoContext : null;
  }

  logout(context: AuthContext, body: JsonObject): Promise<void> {
    if (context.sessionId === portfolioDemoContext.sessionId) {
      return Promise.resolve();
    }
    return this.delegate.logout(context, body);
  }

  deleteAccount(context: AuthContext, body: JsonObject): Promise<JsonObject> {
    return this.delegate.deleteAccount(context, body);
  }
}
