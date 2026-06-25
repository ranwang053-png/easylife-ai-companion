import { randomUUID } from "node:crypto";
import type { ErrorRequestHandler, RequestHandler, Response } from "express";

import type { AppConfig } from "./config.js";
import type { AuthService } from "./auth/auth-service.js";
import type { ErrorBody, ErrorCode } from "./types.js";

const localPreviewOriginPattern = /^https?:\/\/(127\.0\.0\.1|localhost):\d+$/;

const errorDefinitions: Record<
  ErrorCode,
  { status: number; message: string; retryAfter?: number }
> = {
  VALIDATION_ERROR: {
    status: 400,
    message: "请求内容不符合接口要求",
  },
  UNAUTHORIZED: {
    status: 401,
    message: "登录状态无效或已经过期",
  },
  PAYLOAD_TOO_LARGE: {
    status: 413,
    message: "请求内容过长",
  },
  SMS_CODE_EXPIRED: {
    status: 410,
    message: "验证码已失效，请重新获取",
  },
  SMS_CODE_INVALID: {
    status: 422,
    message: "验证码错误",
  },
  VERIFICATION_ATTEMPTS_EXCEEDED: {
    status: 429,
    message: "验证次数过多，请重新获取验证码",
    retryAfter: 60,
  },
  SMS_PROVIDER_UNAVAILABLE: {
    status: 503,
    message: "短信服务暂时不可用",
    retryAfter: 60,
  },
  INVALID_REFRESH_TOKEN: {
    status: 401,
    message: "登录状态已失效，请重新登录",
  },
  INVALID_SYNC_CURSOR: {
    status: 400,
    message: "同步位置已失效，请重新执行完整同步",
  },
  DELETION_VERIFICATION_EXPIRED: {
    status: 410,
    message: "注销验证已失效，请重新验证手机号",
  },
  AI_OUTPUT_INVALID: {
    status: 422,
    message: "暂时无法生成有效的情绪分析结果",
  },
  RATE_LIMITED: {
    status: 429,
    message: "请求过于频繁，请稍后再试",
    retryAfter: 30,
  },
  AI_PROVIDER_UNAVAILABLE: {
    status: 503,
    message: "情绪分析服务暂时不可用",
    retryAfter: 30,
  },
};

export function requestContext(config: AppConfig): RequestHandler {
  return (request, response, next) => {
    const incomingRequestId = request.header("X-Request-Id");
    request.requestId =
      incomingRequestId !== undefined &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        incomingRequestId,
      )
        ? incomingRequestId
        : randomUUID();

    response.setHeader("X-Request-Id", request.requestId);

    if (config.logLevel === "silent") {
      next();
      return;
    }

    const startedAt = process.hrtime.bigint();
    response.on("finish", () => {
      const durationMs =
        Number(process.hrtime.bigint() - startedAt) / 1_000_000;

      console.info(
        JSON.stringify({
          event: "http_request",
          requestId: request.requestId,
          method: request.method,
          route: request.route?.path ?? request.path,
          status: response.statusCode,
          durationMs: Math.round(durationMs),
        }),
      );
    });

    next();
  };
}

export const localCors: RequestHandler = (request, response, next) => {
  const origin = request.header("Origin");
  if (origin !== undefined && localPreviewOriginPattern.test(origin)) {
    response.setHeader("Access-Control-Allow-Origin", origin);
    response.setHeader("Vary", "Origin");
    response.setHeader(
      "Access-Control-Allow-Headers",
      "Authorization, Content-Type, X-Request-Id, X-Easylife-Test-Error, X-Easylife-Test-Sms-Purpose",
    );
    response.setHeader(
      "Access-Control-Allow-Methods",
      "GET, POST, DELETE, OPTIONS",
    );
  }

  if (request.method === "OPTIONS") {
    response.status(204).send();
    return;
  }

  next();
};

export function requireBearerToken(
  authService: AuthService,
  options: { allowRevoked?: boolean } = {},
): RequestHandler {
  return async (request, response, next) => {
    const authorization = request.header("Authorization");
    const token = authorization?.match(/^Bearer ([^\s]+)$/)?.[1];
    if (token === undefined) {
      sendError(response, request.requestId, "UNAUTHORIZED");
      return;
    }

    try {
      const context = await authService.authenticateAccessToken(token, options);
      if (context === null) {
        sendError(response, request.requestId, "UNAUTHORIZED");
        return;
      }
      request.auth = context;
      next();
    } catch {
      sendError(response, request.requestId, "UNAUTHORIZED");
    }
  };
}

export function sendError(
  response: Response,
  requestId: string,
  code: ErrorCode,
): void {
  const definition = errorDefinitions[code];
  const body: ErrorBody = {
    error: {
      code,
      message: definition.message,
      requestId,
    },
  };

  if (definition.retryAfter !== undefined) {
    response.setHeader("Retry-After", definition.retryAfter);
  }

  response.status(definition.status).json(body);
}

export function testErrorTrigger(
  config: AppConfig,
  allowedCodes: readonly ErrorCode[],
): RequestHandler {
  return (request, response, next) => {
    if (!config.enableTestTriggers) {
      next();
      return;
    }

    const requestedCode = request.header("X-Easylife-Test-Error");

    if (
      requestedCode !== undefined &&
      allowedCodes.includes(requestedCode as ErrorCode)
    ) {
      sendError(response, request.requestId, requestedCode as ErrorCode);
      return;
    }

    next();
  };
}

export const errorHandler: ErrorRequestHandler = (
  error: unknown,
  request,
  response,
  _next,
) => {
  if (
    error !== null &&
    typeof error === "object" &&
    "type" in error &&
    error.type === "entity.too.large"
  ) {
    sendError(response, request.requestId ?? randomUUID(), "PAYLOAD_TOO_LARGE");
    return;
  }

  sendError(response, request.requestId ?? randomUUID(), "VALIDATION_ERROR");
};
