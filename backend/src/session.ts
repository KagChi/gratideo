import type { Context } from "hono";

import { sha256Hex } from "./crypto";
import type { Account, AppEnv } from "./types";
import { fail } from "./types";

interface SessionRow {
  id: string;
  email: string;
  name: string;
  verifier_hmac: string;
  kdf_iterations: number;
  created_at: string;
  expires_at: string;
}

export const requireUser = async (context: Context<AppEnv>, next: () => Promise<void>) => {
  const header = context.req.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return fail(context, 401, "unauthorized", "Sign in to continue.");

  const tokenHash = await sha256Hex(token);
  const row = await context.env.DB.prepare(
    `SELECT u.id, u.email, u.name, u.verifier_hmac, u.kdf_iterations, u.created_at, s.expires_at
       FROM sessions s JOIN users u ON u.id = s.user_id
      WHERE s.token_hash = ?`,
  )
    .bind(tokenHash)
    .first<SessionRow>();

  if (!row) return fail(context, 401, "unauthorized", "Sign in to continue.");
  if (row.expires_at <= new Date().toISOString()) {
    await context.env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(tokenHash).run();
    return fail(context, 401, "unauthorized", "Your session expired. Sign in again.");
  }

  const account: Account = {
    id: row.id,
    email: row.email,
    name: row.name,
    createdAt: row.created_at,
  };
  context.set("user", account);
  context.set("tokenHash", tokenHash);
  await next();
};

