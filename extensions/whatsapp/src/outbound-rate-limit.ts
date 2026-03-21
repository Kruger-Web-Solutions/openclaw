import { createSubsystemLogger } from "openclaw/plugin-sdk/runtime-env";

const rateLimitLog = createSubsystemLogger("gateway/channels/whatsapp").child("outbound-rate-limit");

export type OutboundRateLimitConfig = {
  /** Maximum outbound messages per sliding window. Default: 30. */
  maxMessages?: number;
  /** Sliding window duration in seconds. Default: 60. */
  windowSeconds?: number;
};

const DEFAULT_MAX_MESSAGES = 30;
const DEFAULT_WINDOW_SECONDS = 60;

export class WhatsAppRateLimitError extends Error {
  readonly retryAfterMs: number;
  constructor(
    retryAfterMs: number,
    windowConfig: { maxMessages: number; windowSeconds: number },
  ) {
    super(
      `Outbound rate limit exceeded (${windowConfig.maxMessages} messages in ${windowConfig.windowSeconds}s). Retry in ${Math.ceil(retryAfterMs / 1000)}s.`,
    );
    this.name = "WhatsAppRateLimitError";
    this.retryAfterMs = retryAfterMs;
  }
}

export type OutboundRateLimiter = {
  acquire(): { ok: true } | { ok: false; retryAfterMs: number };
  wrapSendMessage<T extends (...args: unknown[]) => Promise<unknown>>(
    original: T,
  ): T;
};

/**
 * Creates a per-account sliding-window outbound rate limiter.
 * Pass `undefined` to get a no-op passthrough (rate limiting disabled).
 */
export function createOutboundRateLimiter(
  config: OutboundRateLimitConfig | undefined,
): OutboundRateLimiter {
  if (!config) {
    return createPassthroughLimiter();
  }

  const maxMessages = config.maxMessages ?? DEFAULT_MAX_MESSAGES;
  const windowSeconds = config.windowSeconds ?? DEFAULT_WINDOW_SECONDS;
  const windowMs = windowSeconds * 1000;

  // Sliding window: timestamps of recent sends
  const timestamps: number[] = [];
  let firstRejectionInWindow = true;

  function prune(now: number): void {
    const cutoff = now - windowMs;
    let i = 0;
    while (i < timestamps.length && timestamps[i]! <= cutoff) {
      i++;
    }
    if (i > 0) {
      timestamps.splice(0, i);
    }
  }

  function acquire(): { ok: true } | { ok: false; retryAfterMs: number } {
    const now = Date.now();
    prune(now);

    if (timestamps.length < maxMessages) {
      timestamps.push(now);
      firstRejectionInWindow = true;
      return { ok: true };
    }

    // Window is full -- compute how long until the oldest entry expires
    const oldest = timestamps[0]!;
    const retryAfterMs = oldest + windowMs - now;

    if (firstRejectionInWindow) {
      firstRejectionInWindow = false;
      rateLimitLog.warn(
        `Rate limit reached: ${timestamps.length}/${maxMessages} messages in ${windowSeconds}s window. Retry in ${Math.ceil(retryAfterMs / 1000)}s.`,
      );
    } else {
      rateLimitLog.debug(
        `Rate limit still active: retry in ${Math.ceil(retryAfterMs / 1000)}s.`,
      );
    }

    return { ok: false, retryAfterMs };
  }

  function wrapSendMessage<T extends (...args: unknown[]) => Promise<unknown>>(
    original: T,
  ): T {
    return (async (...args: unknown[]) => {
      const result = acquire();
      if (!result.ok) {
        throw new WhatsAppRateLimitError(result.retryAfterMs, {
          maxMessages,
          windowSeconds,
        });
      }
      return original(...args);
    }) as T;
  }

  return { acquire, wrapSendMessage };
}

function createPassthroughLimiter(): OutboundRateLimiter {
  return {
    acquire: () => ({ ok: true }),
    wrapSendMessage: <T extends (...args: unknown[]) => Promise<unknown>>(
      original: T,
    ) => original,
  };
}
