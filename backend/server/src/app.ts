import express, {
  type RequestHandler,
  type Response,
} from "express";

import type { AppConfig } from "./config.js";
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
import type {
  EmotionAnalyzeResponse,
  JsonObject,
} from "./types.js";

interface AppDependencies {
  config: AppConfig;
  emotionProvider?: EmotionProvider;
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

  app.disable("x-powered-by");
  app.use(localCors);
  app.use(requestContext(config));
  app.use(express.json({ limit: "256kb" }));

  app.get("/v1/health", (_request, response) => {
    response.json({
      status: "ok",
      service: "easylife-fixed-api",
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
    (_request, response) => {
      sendExample(response, 200, "SendSmsCodeResponse");
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
    (request, response) => {
      if (
        config.enableTestTriggers &&
        request.header("X-Easylife-Test-Sms-Purpose") ===
          "account_deletion"
      ) {
        response.json({
          purpose: "account_deletion",
          deletionToken:
            "example-deletion-token-with-at-least-twenty-characters",
          expiresIn: 600,
        });
        return;
      }

      sendExample(response, 200, "LoginVerificationResponse");
    },
  );

  app.post(
    "/v1/auth/token/refresh",
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "INVALID_REFRESH_TOKEN",
    ]),
    validateBody("RefreshTokenRequest"),
    (_request, response) => {
      response.json({
        accessToken:
          "rotated-access-token-with-at-least-twenty-characters",
        accessTokenExpiresIn: 900,
        refreshToken:
          "rotated-refresh-token-with-at-least-twenty-characters",
        refreshTokenExpiresIn: 2592000,
      });
    },
  );

  app.post(
    "/v1/auth/logout",
    requireBearerToken(config),
    testErrorTrigger(config, ["VALIDATION_ERROR"]),
    validateBody("LogoutRequest"),
    (_request, response) => {
      response.status(204).send();
    },
  );

  app.post(
    "/v1/emotion/analyze",
    requireBearerToken(config),
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
        sendError(
          response,
          request.requestId,
          "AI_PROVIDER_UNAVAILABLE",
        );
      }
    },
  );

  app.post(
    "/v1/sync/push",
    requireBearerToken(config),
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "PAYLOAD_TOO_LARGE",
    ]),
    validateBody("SyncPushRequest"),
    (_request, response) => {
      sendExample(response, 200, "SyncPushResponse");
    },
  );

  app.get(
    "/v1/sync/pull",
    requireBearerToken(config),
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
    requireBearerToken(config),
    testErrorTrigger(config, [
      "VALIDATION_ERROR",
      "DELETION_VERIFICATION_EXPIRED",
    ]),
    validateBody("DeleteAccountRequest"),
    (_request, response) => {
      sendExample(response, 202, "DeleteAccountResponse");
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
