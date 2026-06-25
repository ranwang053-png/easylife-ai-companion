export type SmsPurpose = "login" | "account_deletion";

export interface SmsProvider {
  sendCode(input: {
    phone: string;
    code: string;
    purpose: SmsPurpose;
    requestId: string;
    idempotencyKey: string;
  }): Promise<{ messageId?: string }>;
}

export class WebhookSmsProvider implements SmsProvider {
  constructor(
    private readonly endpoint: URL,
    private readonly bearerToken: string,
    private readonly maxAttempts = 3,
  ) {}

  async sendCode(input: {
    phone: string;
    code: string;
    purpose: SmsPurpose;
    requestId: string;
    idempotencyKey: string;
  }): Promise<{ messageId?: string }> {
    for (let attempt = 1; attempt <= this.maxAttempts; attempt += 1) {
      try {
        const response = await fetch(this.endpoint, {
          method: "POST",
          headers: {
            authorization: `Bearer ${this.bearerToken}`,
            "content-type": "application/json",
            "idempotency-key": input.idempotencyKey,
            "x-request-id": input.requestId,
          },
          body: JSON.stringify({
            phone: input.phone,
            code: input.code,
            purpose: input.purpose,
          }),
          signal: AbortSignal.timeout(8_000),
        });

        if (response.ok) {
          return await safeReceipt(response);
        }
        if (
          attempt === this.maxAttempts ||
          (response.status !== 429 && response.status < 500)
        ) {
          throw new SmsProviderError("sms_gateway_rejected");
        }
        await delay(retryDelay(response, attempt));
      } catch (error) {
        if (error instanceof SmsProviderError || attempt === this.maxAttempts) {
          throw error;
        }
        await delay(100 * 2 ** (attempt - 1));
      }
    }
    throw new SmsProviderError("sms_gateway_unavailable");
  }
}

export class SmsProviderError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "SmsProviderError";
  }
}

async function safeReceipt(
  response: Response,
): Promise<{ messageId?: string }> {
  try {
    const body = (await response.json()) as { messageId?: unknown };
    return typeof body.messageId === "string" &&
      body.messageId.length >= 1 &&
      body.messageId.length <= 200
      ? { messageId: body.messageId }
      : {};
  } catch {
    return {};
  }
}

function retryDelay(response: Response, attempt: number): number {
  const retryAfter = Number.parseInt(
    response.headers.get("retry-after") ?? "",
    10,
  );
  if (Number.isInteger(retryAfter) && retryAfter >= 0) {
    return Math.min(retryAfter * 1000, 5_000);
  }
  return 100 * 2 ** (attempt - 1);
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
