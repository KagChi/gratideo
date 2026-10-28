import { Hono } from "hono";
import { z } from "zod";

import {
  constantTimeEquals,
  hmacBase64,
  normalizeEmail,
  randomToken,
  sha256Hex,
} from "./crypto";
import { requireUser } from "./session";
import { sync } from "./sync";
import type { AppEnv, Env } from "./types";
import { fail, readJson } from "./types";

interface UserRow {
  id: string;
  email: string;
  name: string;
  verifier_hmac: string;
  kdf_iterations: number;
  created_at: string;
}

const SESSION_DAYS = 30;
const MIN_ITERATIONS = 100_000;
const MAX_ITERATIONS = 2_000_000;
const DEFAULT_ITERATIONS = 210_000;

const emailSchema = z.string().trim().min(3).max(254).email();
const verifierSchema = z
  .string()
  .min(20)
  .max(200)
  .regex(/^[A-Za-z0-9+/=_-]+$/);

const registerSchema = z.object({
  name: z.string().trim().min(1).max(80),
  email: emailSchema,
  verifier: verifierSchema,
  kdf: z
    .object({
      algo: z.literal("pbkdf2-sha256"),
      iterations: z.number().int().min(MIN_ITERATIONS).max(MAX_ITERATIONS),
    })
    .optional(),
});

const loginSchema = z.object({ email: emailSchema, verifier: verifierSchema });

async function createSession(env: Env, userId: string, now = new Date()) {
  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const expiresAt = new Date(now.getTime() + SESSION_DAYS * 86_400_000).toISOString();
  await env.DB.prepare(
    "INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
  )
    .bind(tokenHash, userId, now.toISOString(), expiresAt)
    .run();
  return { token, expiresAt };
}

const app = new Hono<AppEnv>();

app.use("/v1/auth/*", async (context, next) => {
  const limiter = context.env.AUTH_RATE_LIMITER;
  if (limiter) {
    const ip = context.req.header("CF-Connecting-IP") ?? "unknown";
    const { success } = await limiter.limit({ key: ip });
    if (!success) {
      return fail(context, 429, "rate_limited", "Too many attempts. Try again in a minute.");
    }
  }
  await next();
});

app.get("/health", (context) => context.json({ ok: true }));

app.post("/v1/auth/register", async (context) => {
  const parsed = registerSchema.safeParse(await readJson(context));
  if (!parsed.success) {
    return fail(context, 400, "invalid_request", "Check the details you sent.");
  }

  const email = normalizeEmail(parsed.data.email);
  const existing = await context.env.DB.prepare("SELECT id FROM users WHERE email = ?")
    .bind(email)
    .first<{ id: string }>();
  if (existing) {
    return fail(context, 409, "email_taken", "An account with this email already exists.");
  }

  const now = new Date();
  const user: UserRow = {
    id: crypto.randomUUID(),
    email,
    name: parsed.data.name,
    verifier_hmac: await hmacBase64(context.env.PEPPER, parsed.data.verifier),
    kdf_iterations: parsed.data.kdf?.iterations ?? DEFAULT_ITERATIONS,
    created_at: now.toISOString(),
  };

  try {
    await context.env.DB.prepare(
      `INSERT INTO users (id, email, name, verifier_hmac, kdf_algo, kdf_iterations, created_at)
       VALUES (?, ?, ?, ?, 'pbkdf2-sha256', ?, ?)`,
    )
      .bind(user.id, user.email, user.name, user.verifier_hmac, user.kdf_iterations, user.created_at)
      .run();
  } catch {
    return fail(context, 409, "email_taken", "An account with this email already exists.");
  }

  const session = await createSession(context.env, user.id, now);
  return context.json(
    {
      token: session.token,
      expiresAt: session.expiresAt,
      user: { id: user.id, email: user.email, name: user.name, createdAt: user.created_at },
    },
    201,
  );
});

app.post("/v1/auth/login", async (context) => {
  const parsed = loginSchema.safeParse(await readJson(context));
  if (!parsed.success) {
    return fail(context, 400, "invalid_request", "Check the details you sent.");
  }

  const email = normalizeEmail(parsed.data.email);
  const user = await context.env.DB.prepare(
    "SELECT id, email, name, verifier_hmac, kdf_iterations, created_at FROM users WHERE email = ?",
  )
    .bind(email)
    .first<UserRow>();

  const candidate = await hmacBase64(context.env.PEPPER, parsed.data.verifier);
  const expected = user?.verifier_hmac ?? "A".repeat(44);
  const matches = constantTimeEquals(candidate, expected);

  if (!user || !matches) {
    return fail(context, 401, "invalid_credentials", "Email or password is incorrect.");
  }

  await context.env.DB.prepare("DELETE FROM sessions WHERE user_id = ? AND expires_at <= ?")
    .bind(user.id, new Date().toISOString())
    .run();

  const session = await createSession(context.env, user.id);
  return context.json({
    token: session.token,
    expiresAt: session.expiresAt,
    user: { id: user.id, email: user.email, name: user.name, createdAt: user.created_at },
  });
});

app.get("/v1/auth/me", requireUser, (context) => context.json({ user: context.get("user") }));

app.post("/v1/auth/logout", requireUser, async (context) => {
  await context.env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?")
    .bind(context.get("tokenHash"))
    .run();
  return context.body(null, 204);
});

app.post("/v1/auth/password/reset-request", async (context) => {
  const parsed = z.object({ email: emailSchema }).safeParse(await readJson(context));
  if (!parsed.success) {
    return fail(context, 400, "invalid_request", "Enter a valid email address.");
  }
  // No mail transport yet: answer the same way whether or not the account exists.
  return context.json({ status: "accepted" }, 202);
});

app.route("/v1/sync", sync);

app.notFound((context) => fail(context, 404, "not_found", "Unknown endpoint."));

app.onError((error, context) => {
  console.error("unhandled", error instanceof Error ? error.message : String(error));
  return fail(context, 500, "server_error", "Something went wrong. Please try again.");
});

export default app;
export { app };

