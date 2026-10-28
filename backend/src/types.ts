import type { Context } from "hono";

export interface Env {
  DB: D1Database;
  PEPPER: string;
  AUTH_RATE_LIMITER?: {
    limit(options: { key: string }): Promise<{ success: boolean }>;
  };
}

export interface Account {
  id: string;
  email: string;
  name: string;
  createdAt: string;
}

export type Variables = { user: Account; tokenHash: string };
export type AppEnv = { Bindings: Env; Variables: Variables };
export type Status = 400 | 401 | 404 | 409 | 429 | 500;

export function fail(context: Context<AppEnv>, status: Status, code: string, message: string) {
  return context.json({ error: { code, message } }, status);
}

export async function readJson(context: Context<AppEnv>): Promise<unknown> {
  try {
    return await context.req.json();
  } catch {
    return null;
  }
}

