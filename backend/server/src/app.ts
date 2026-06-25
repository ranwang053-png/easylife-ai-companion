import express, { type RequestHandler, type Response } from "express";

import type { AppConfig } from "./config.js";
import { AuthServiceError, type AuthService } from "./auth/auth-service.js";
import { FixedAuthService } from "./auth/fixed-auth-service.js";
import {
  contractExample,
  contractVersion,
  validateContractSchema,
} from "./contract.js";
import {
  errorHandler,
  localCors,
  requestContext,
  requireBearerToken,
  sendError,
  testErrorTrigger,
} from "./http.js";
import { FixedEmotionProvider } from "./providers/fixed-emotion-provider.js";
import type { EmotionProvider } from "./providers/emotion-provider.js";
import type { EmotionAnalyzeResponse, JsonObject } from "./types.js";

interface AppDependencies {
  config: AppConfig;
  emotionProvider?: EmotionProvider;
  authService?: AuthService;
}

function validateBody(schemaName: string): RequestHandler {
  return (request, response, next) => {
    const validation = validateContractSchema(schemaName, request.body);

    if (!validation.valid) {
      sendError(response, request.requestId, "VALIDATION_ERROR");
      return;
    }

    next();
  };
}

function sendExample(
  response: Response,
  status: number,
  exampleName: string,
): void {
  response.status(status).json(contractExample(exampleName));
}

export function createApp(dependencies: AppDependencies) {
  const app = express();
  const emotionProvider =
    dependencies.emotionProvider ?? new FixedEmotionProvider();
  const { config } = dependencies;
  if (
    config.nodeEnv !== "development" &&
    config.nodeEnv !== "test" &&
    dependencies.authService === undefined
  ) {
    throw new Error(
      "A database-backed AuthService is required outside development and test",
    );
  }
  const authService = dependencies.authService ?? new FixedAuthService(config);

  app.disable("x-powered-by");
  if (config.auth?.trustProxy === true) {
    app.set("trust proxy", 1);
  }
  app.use(localCors);
  app.use(requestContext(config));
  app.use(express.json({ limit: "256kb" }));

  app.get("/v1/health", (_request, response) => {
    response.json({
      status: "ok",
      service: "easylife-api",
      contractVersion,
    });
  });

  app.post(
    "/v1/auth/sms/codes",
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "RATE_LIMITED",
      "SMS_PROVIDER_UNAVAILABLE",
    ]),
    validateBody("SendSmsCodeRequest"),
    async (request, response) => {
      try {
        const result = await authService.sendSmsCode(
          request.body as JsonObject,
          request,
        );
        response.json(result);
      } catch (error) {
        sendAuthError(
          response,
          request.requestId,
          error,
          "SMS_PROVIDER_UNAVAILABLE",
        );
      }
    },
  );

  app.post(
    "/v1/auth/sms/verify",
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "SMS_CODE_EXPIRED",
      "SMS_CODE_INVALID",
      "VERIFICATION_ATTEMPTS_EXCEEDED",
    ]),
    validateBody("VerifySmsCodeRequest"),
    async (request, response) => {
      try {
        const result = await authService.verifySmsCode(
          request.body as JsonObject,
          request,
        );
        response.json(result);
      } catch (error) {
        sendAuthError(response, request.requestId, error, "SMS_CODE_EXPIRED");
      }
    },
  );

  app.post(
    "/v1/auth/token/refresh",
    testErrorTrigger(config, ["VALIDATION_ERROR", "INVALID_REFRESH_TOKEN"]),
    validateBody("RefreshTokenRequest"),
    async (request, response) => {
      try {
        const result = await authService.refreshTokens(
          request.body as JsonObject,
        );
        response.json(result);
      } catch (error) {
        sendAuthError(
          response,
          request.requestId,
          error,
          "INVALID_REFRESH_TOKEN",
        );
      }
    },
  );

  app.post(
    "/v1/auth/logout",
    requireBearerToken(authService, { allowRevoked: true }),
    testErrorTrigger(config, ["VALIDATION_ERROR"]),
    validateBody("LogoutRequest"),
    async (request, response) => {
      try {
        await authService.logout(
          requireAuthContext(request),
          request.body as JsonObject,
        );
        response.status(204).send();
      } catch (error) {
        sendAuthError(response, request.requestId, error, "UNAUTHORIZED");
      }
    },
  );

  app.post(
    "/v1/emotion/analyze",
    requireBearerToken(authService),
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "PAYLOAD_TOO_LARGE",
      "AI_OUTPUT_INVALID",
      "RATE_LIMITED",
      "AI_PROVIDER_UNAVAILABLE",
    ]),
    validateBody("EmotionAnalyzeRequest"),
    async (request, response) => {
      try {
        const result = await emotionProvider.analyze(
          request.body as JsonObject,
        );
        const validation = validateContractSchema(
          "EmotionAnalyzeResponse",
          result,
        );

        if (!validation.valid) {
          sendError(response, request.requestId, "AI_OUTPUT_INVALID");
          return;
        }

        response.json(result satisfies EmotionAnalyzeResponse);
      } catch (error) {
        void error;
        sendError(response, request.requestId, "AI_PROVIDER_UNAVAILABLE");
      }
    },
  );

  app.post(
    "/v1/sync/push",
    requireBearerToken(authService),
    testErrorTrigger(config, ["VALIDATION_ERROR", "PAYLOAD_TOO_LARGE"]),
    validateBody("SyncPushRequest"),
    (_request, response) => {
      sendExample(response, 200, "SyncPushResponse");
    },
  );

  app.get(
    "/v1/sync/pull",
    requireBearerToken(authService),
    testErrorTrigger(config, ["INVALID_SYNC_CURSOR"]),
    (request, response) => {
      const cursor = request.query.cursor;
      const limit = request.query.limit;
      const validCursor =
        cursor === undefined ||
        (typeof cursor === "string" && cursor.length <= 500);
      const parsedLimit =
        limit === undefined ? 100 : Number.parseInt(String(limit), 10);
      const validLimit =
        Number.isInteger(parsedLimit) &&
        parsedLimit >= 1 &&
        parsedLimit <= 200 &&
        String(parsedLimit) === String(limit ?? 100);

      if (!validCursor || !validLimit) {
        sendError(response, request.requestId, "INVALID_SYNC_CURSOR");
        return;
      }

      sendExample(response, 200, "SyncPullResponse");
    },
  );

  app.delete(
    "/v1/me/account",
    requireBearerToken(authService),
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "DELETION_VERIFICATION_EXPIRED",
    ]),
    validateBody("DeleteAccountRequest"),
    async (request, response) => {
      try {
        const result = await authService.deleteAccount(
          requireAuthContext(request),
          request.body as JsonObject,
        );
        response.status(202).json(result);
      } catch (error) {
        sendAuthError(
          response,
          request.requestId,
          error,
          "DELETION_VERIFICATION_EXPIRED",
        );
      }
    },
  );

  app.use((_request, response) => {
    response.status(404).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "请求的接口不存在",
        requestId: response.getHeader("X-Request-Id"),
      },
    });
  });

  app.use(errorHandler);

  return app;
}

function requireAuthContext(request: express.Request) {
  if (request.auth === undefined) {
    throw new AuthServiceError("UNAUTHORIZED");
  }
  return request.auth;
}

function sendAuthError(
  response: Response,
  requestId: string,
  error: unknown,
  fallback: import("./types.js").ErrorCode,
): void {
  sendError(
    response,
    requestId,
    error instanceof AuthServiceError ? error.code : fallback,
  );
}
