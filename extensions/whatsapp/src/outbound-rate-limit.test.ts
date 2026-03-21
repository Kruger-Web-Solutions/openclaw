import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  createOutboundRateLimiter,
  WhatsAppRateLimitError,
} from "./outbound-rate-limit.js";

// Silence the logger in tests
vi.mock("openclaw/plugin-sdk/runtime-env", () => ({
  createSubsystemLogger: () => ({
    child: () => ({
      warn: vi.fn(),
      debug: vi.fn(),
    }),
  }),
}));

describe("createOutboundRateLimiter", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe("passthrough (undefined config)", () => {
    it("always allows sends when config is undefined", () => {
      const limiter = createOutboundRateLimiter(undefined);
      for (let i = 0; i < 1000; i++) {
        expect(limiter.acquire()).toEqual({ ok: true });
      }
    });

    it("returns the original function unchanged from wrapSendMessage", async () => {
      const limiter = createOutboundRateLimiter(undefined);
      const fn = vi.fn().mockResolvedValue("result");
      const wrapped = limiter.wrapSendMessage(fn);
      expect(wrapped).toBe(fn);
    });
  });

  describe("acquire()", () => {
    it("allows up to maxMessages within the window", () => {
      const limiter = createOutboundRateLimiter({
        maxMessages: 5,
        windowSeconds: 60,
      });
      for (let i = 0; i < 5; i++) {
        expect(limiter.acquire()).toEqual({ ok: true });
      }
    });

    it("rejects after maxMessages is reached", () => {
      const limiter = createOutboundRateLimiter({
        maxMessages: 3,
        windowSeconds: 60,
      });
      for (let i = 0; i < 3; i++) {
        limiter.acquire();
      }
      const result = limiter.acquire();
      expect(result.ok).toBe(false);
    });

    it("returns correct retryAfterMs on rejection", () => {
      vi.setSystemTime(0);
      const limiter = createOutboundRateLimiter({
        maxMessages: 2,
        windowSeconds: 10,
      });
      // Fill at t=0
      limiter.acquire(); // t=0
      vi.advanceTimersByTime(3000); // t=3s
      limiter.acquire(); // t=3
      // Now window: [0, 3000]. Oldest is 0. Window expires at 0 + 10000 = 10000.
      // Current time = 3000. retryAfterMs = 10000 - 3000 = 7000
      const result = limiter.acquire();
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.retryAfterMs).toBe(7000);
      }
    });

    it("allows sends again after the window expires", () => {
      vi.setSystemTime(0);
      const limiter = createOutboundRateLimiter({
        maxMessages: 2,
        windowSeconds: 10,
      });
      limiter.acquire();
      limiter.acquire();
      expect(limiter.acquire().ok).toBe(false);

      // Advance past the window
      vi.advanceTimersByTime(11000);
      expect(limiter.acquire()).toEqual({ ok: true });
      expect(limiter.acquire()).toEqual({ ok: true });
      expect(limiter.acquire().ok).toBe(false);
    });

    it("uses default values (30 messages / 60s) when not specified", () => {
      vi.setSystemTime(0);
      const limiter = createOutboundRateLimiter({});
      for (let i = 0; i < 30; i++) {
        expect(limiter.acquire()).toEqual({ ok: true });
      }
      const over = limiter.acquire();
      expect(over.ok).toBe(false);
      if (!over.ok) {
        // retryAfterMs should be close to 60000ms
        expect(over.retryAfterMs).toBeGreaterThan(0);
        expect(over.retryAfterMs).toBeLessThanOrEqual(60000);
      }
    });
  });

  describe("wrapSendMessage()", () => {
    it("calls the original function when under the limit", async () => {
      const limiter = createOutboundRateLimiter({
        maxMessages: 5,
        windowSeconds: 60,
      });
      const original = vi.fn().mockResolvedValue({ messageId: "msg-1" });
      const wrapped = limiter.wrapSendMessage(original);

      const result = await wrapped("jid@s.whatsapp.net", { text: "hello" });
      expect(result).toEqual({ messageId: "msg-1" });
      expect(original).toHaveBeenCalledWith("jid@s.whatsapp.net", {
        text: "hello",
      });
    });

    it("throws WhatsAppRateLimitError when the limit is exceeded", async () => {
      const limiter = createOutboundRateLimiter({
        maxMessages: 2,
        windowSeconds: 60,
      });
      const original = vi.fn().mockResolvedValue({});
      const wrapped = limiter.wrapSendMessage(original);

      await wrapped();
      await wrapped();
      await expect(wrapped()).rejects.toThrow(WhatsAppRateLimitError);
    });

    it("WhatsAppRateLimitError has correct retryAfterMs", async () => {
      vi.setSystemTime(0);
      const limiter = createOutboundRateLimiter({
        maxMessages: 1,
        windowSeconds: 30,
      });
      const wrapped = limiter.wrapSendMessage(vi.fn().mockResolvedValue({}));
      await wrapped();

      vi.advanceTimersByTime(5000);
      try {
        await wrapped();
        expect.fail("Should have thrown");
      } catch (err) {
        expect(err).toBeInstanceOf(WhatsAppRateLimitError);
        expect((err as WhatsAppRateLimitError).retryAfterMs).toBe(25000);
      }
    });

    it("does not count the original function call if acquire is called separately", async () => {
      const limiter = createOutboundRateLimiter({
        maxMessages: 3,
        windowSeconds: 60,
      });
      const original = vi.fn().mockResolvedValue({});
      const wrapped = limiter.wrapSendMessage(original);

      // wrapSendMessage calls acquire internally on each call
      await wrapped();
      await wrapped();
      await wrapped();
      await expect(wrapped()).rejects.toThrow(WhatsAppRateLimitError);
    });

    it("does not retry on error from original function (not a connection error)", async () => {
      const limiter = createOutboundRateLimiter({
        maxMessages: 5,
        windowSeconds: 60,
      });
      const original = vi
        .fn()
        .mockRejectedValue(new Error("some other error"));
      const wrapped = limiter.wrapSendMessage(original);
      await expect(wrapped()).rejects.toThrow("some other error");
      expect(original).toHaveBeenCalledTimes(1);
    });
  });

  describe("WhatsAppRateLimitError", () => {
    it("has correct name", () => {
      const err = new WhatsAppRateLimitError(5000, {
        maxMessages: 10,
        windowSeconds: 60,
      });
      expect(err.name).toBe("WhatsAppRateLimitError");
    });

    it("includes maxMessages and windowSeconds in message", () => {
      const err = new WhatsAppRateLimitError(5000, {
        maxMessages: 10,
        windowSeconds: 60,
      });
      expect(err.message).toContain("10");
      expect(err.message).toContain("60");
    });

    it("retryAfterMs is set correctly", () => {
      const err = new WhatsAppRateLimitError(7500, {
        maxMessages: 5,
        windowSeconds: 30,
      });
      expect(err.retryAfterMs).toBe(7500);
    });

    it("shows retry seconds in message (rounded up)", () => {
      const err = new WhatsAppRateLimitError(7500, {
        maxMessages: 5,
        windowSeconds: 30,
      });
      expect(err.message).toContain("8s"); // ceil(7500/1000) = 8
    });

    it("is instanceof Error", () => {
      const err = new WhatsAppRateLimitError(1000, {
        maxMessages: 1,
        windowSeconds: 1,
      });
      expect(err).toBeInstanceOf(Error);
      expect(err).toBeInstanceOf(WhatsAppRateLimitError);
    });
  });
});
