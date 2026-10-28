import { env } from "cloudflare:workers";
import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

import { app } from "../src/app";

const BASE = "https://gratideo.test";
const VERIFIER = "dGhpcy1pcy1hLXRlc3QtdmVyaWZpZXItNDQtY2hhcnM=";
const WRONG_VERIFIER = "d3JvbmctdmVyaWZpZXItc2hvdWxkLWZhaWwtNDQtY2hhcnM=";

// Storage is shared by every test in this file, so each registration uses a
// fresh address and a fresh client IP.
let counter = 0;
function uniqueEmail(): string {
  counter += 1;
  return `user${counter}.${Date.now()}@example.com`;
}

function headers(token?: string): Record<string, string> {
  return {
    "content-type": "application/json",
    "cf-connecting-ip": `198.51.100.${((counter % 200) + 1).toString()}`,
    ...(token ? { authorization: `Bearer ${token}` } : {}),
  };
}

async function post(path: string, body: unknown, token?: string): Promise<Response> {
  return SELF.fetch(BASE + path, {
    method: "POST",
    headers: headers(token),
    body: JSON.stringify(body),
  });
}

async function me(token?: string): Promise<Response> {
  return SELF.fetch(BASE + "/v1/auth/me", { headers: headers(token) });
}

async function register(email?: string) {
  const address = email ?? uniqueEmail();
  const response = await post("/v1/auth/register", {
    name: "Test User",
    email: address,
    verifier: VERIFIER,
  });
  return { response, body: (await response.json()) as any, email: address.toLowerCase() };
}

describe("health", () => {
  it("answers", async () => {
    const response = await SELF.fetch(BASE + "/health", { headers: headers() });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
  });
});

describe("register", () => {
  it("creates an account, normalises the email and returns a working token", async () => {
    const { response, body, email } = await register(`Mixed.Case.${Date.now()}@Example.COM`);
    expect(response.status).toBe(201);
    expect(typeof body.token).toBe("string");
    expect(body.user.email).toBe(email);
    expect(email).toBe(email.toLowerCase());
    expect(body.user.name).toBe("Test User");

    const current = await me(body.token);
    expect(current.status).toBe(200);
    expect(((await current.json()) as any).user.email).toBe(email);
  });

  it("rejects a second account with the same email", async () => {
    const first = await register();
    const { response, body } = await register(first.email.toUpperCase());
    expect(response.status).toBe(409);
    expect(body.error.code).toBe("email_taken");
  });

  it("rejects a malformed payload", async () => {
    const response = await post("/v1/auth/register", { name: "", email: "nope", verifier: "x" });
    expect(response.status).toBe(400);
    expect(((await response.json()) as any).error.code).toBe("invalid_request");
  });

  it("never stores the verifier itself", async () => {
    const { body } = await register();
    const row = await env.DB.prepare("SELECT verifier_hmac FROM users WHERE id = ?")
      .bind(body.user.id)
      .first<{ verifier_hmac: string }>();
    expect(row?.verifier_hmac).toBeTruthy();
    expect(row?.verifier_hmac).not.toBe(VERIFIER);
  });
});

describe("login", () => {
  it("rejects a wrong verifier with a generic error", async () => {
    const { email } = await register();
    const response = await post("/v1/auth/login", { email, verifier: WRONG_VERIFIER });
    expect(response.status).toBe(401);
    expect(((await response.json()) as any).error.code).toBe("invalid_credentials");
  });

  it("rejects an unknown email the same way", async () => {
    const response = await post("/v1/auth/login", { email: uniqueEmail(), verifier: VERIFIER });
    expect(response.status).toBe(401);
    expect(((await response.json()) as any).error.code).toBe("invalid_credentials");
  });

  it("signs in with the right verifier, ignoring email case", async () => {
    const { email } = await register();
    const response = await post("/v1/auth/login", { email: email.toUpperCase(), verifier: VERIFIER });
    expect(response.status).toBe(200);
    const body = (await response.json()) as any;
    expect((await me(body.token)).status).toBe(200);
  });
});

describe("sessions", () => {
  it("requires a token for /me", async () => {
    const response = await me();
    expect(response.status).toBe(401);
    expect(((await response.json()) as any).error.code).toBe("unauthorized");
  });

  it("revokes the token on logout", async () => {
    const { body } = await register();
    const logout = await post("/v1/auth/logout", {}, body.token);
    expect(logout.status).toBe(204);
    expect((await me(body.token)).status).toBe(401);
  });

  it("refuses an expired session and deletes it", async () => {
    const { body } = await register();
    const expiresAt = new Date(Date.now() - 60_000).toISOString();
    await env.DB.prepare("UPDATE sessions SET expires_at = ? WHERE user_id = ?")
      .bind(expiresAt, body.user.id)
      .run();

    expect((await me(body.token)).status).toBe(401);
    const left = await env.DB.prepare("SELECT COUNT(*) AS n FROM sessions WHERE user_id = ?")
      .bind(body.user.id)
      .first<{ n: number }>();
    expect(left?.n).toBe(0);
  });
});

describe("rate limiting", () => {
  const loginRequest = {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "nobody@example.com", verifier: VERIFIER }),
  };

  it("answers 429 when the platform limiter rejects the caller", async () => {
    const response = await app.request(BASE + "/v1/auth/login", loginRequest, {
      DB: env.DB,
      PEPPER: "test-pepper",
      AUTH_RATE_LIMITER: { limit: async () => ({ success: false }) },
    });
    expect(response.status).toBe(429);
    expect(((await response.json()) as any).error.code).toBe("rate_limited");
  });

  it("still reaches the handler while the limiter allows it", async () => {
    const response = await app.request(BASE + "/v1/auth/login", loginRequest, {
      DB: env.DB,
      PEPPER: "test-pepper",
      AUTH_RATE_LIMITER: { limit: async () => ({ success: true }) },
    });
    expect(response.status).toBe(401);
  });
});

describe("password reset", () => {
  it("always accepts, whether or not the account exists", async () => {
    const { email } = await register();
    for (const address of [email, uniqueEmail()]) {
      const response = await post("/v1/auth/password/reset-request", { email: address });
      expect(response.status).toBe(202);
      expect(await response.json()).toEqual({ status: "accepted" });
    }
  });
});

describe("routing", () => {
  it("returns JSON 404 for unknown endpoints", async () => {
    const response = await SELF.fetch(BASE + "/nope", { headers: headers() });
    expect(response.status).toBe(404);
    expect(((await response.json()) as any).error.code).toBe("not_found");
  });
});

