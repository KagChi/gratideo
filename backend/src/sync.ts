import { Hono } from "hono";
import { z } from "zod";

import { requireUser } from "./session";
import type { AppEnv } from "./types";
import { fail, readJson } from "./types";

const timestamp = z.string().min(10).max(40);
const maybeTimestamp = timestamp.nullable().optional();
const uuid = z.string().min(8).max(64);
const MAX_ROWS = 200;

const prayerSchema = z.object({
  uuid,
  title: z.string().trim().min(1).max(500),
  status: z.enum(["praying", "answered", "waiting", "surrendered"]),
  createdAt: timestamp,
  answeredAt: maybeTimestamp,
  testimony: z.string().max(5000).nullable().optional(),
  updatedAt: timestamp,
  deletedAt: maybeTimestamp,
});

const thanksSchema = z.object({
  uuid,
  text: z.string().trim().min(1).max(1000),
  day: z.string().min(8).max(10),
  updatedAt: timestamp,
  deletedAt: maybeTimestamp,
});

const entrySchema = z.object({
  uuid,
  kind: z.enum(["journal", "selah"]),
  text: z.string().trim().min(1).max(20000),
  decision: z.string().max(500).nullable().optional(),
  createdAt: timestamp,
  updatedAt: timestamp,
  deletedAt: maybeTimestamp,
});

const pushSchema = z.object({
  since: maybeTimestamp,
  prayers: z.array(prayerSchema).max(MAX_ROWS).default([]),
  thanks: z.array(thanksSchema).max(MAX_ROWS).default([]),
  entries: z.array(entrySchema).max(MAX_ROWS).default([]),
});

const PULL_LIMIT = 2000;

const prayerColumns = `uuid, title, status, created_at AS createdAt, answered_at AS answeredAt,
  testimony, updated_at AS updatedAt, deleted_at AS deletedAt`;
const thanksColumns = "uuid, text, day, updated_at AS updatedAt, deleted_at AS deletedAt";
const entryColumns = `uuid, kind, text, decision, created_at AS createdAt,
  updated_at AS updatedAt, deleted_at AS deletedAt`;

async function pull(env: AppEnv["Bindings"], userId: string, since: string) {
  const [prayers, thanks, entries] = await Promise.all([
    env.DB.prepare(
      `SELECT ${prayerColumns} FROM prayers WHERE user_id = ? AND updated_at > ? ORDER BY updated_at LIMIT ${PULL_LIMIT}`,
    )
      .bind(userId, since)
      .all(),
    env.DB.prepare(
      `SELECT ${thanksColumns} FROM thanks WHERE user_id = ? AND updated_at > ? ORDER BY updated_at LIMIT ${PULL_LIMIT}`,
    )
      .bind(userId, since)
      .all(),
    env.DB.prepare(
      `SELECT ${entryColumns} FROM entries WHERE user_id = ? AND updated_at > ? ORDER BY updated_at LIMIT ${PULL_LIMIT}`,
    )
      .bind(userId, since)
      .all(),
  ]);
  return {
    prayers: prayers.results ?? [],
    thanks: thanks.results ?? [],
    entries: entries.results ?? [],
  };
}

export const sync = new Hono<AppEnv>();

sync.use("*", requireUser);

sync.post("/", async (context) => {
  const parsed = pushSchema.safeParse(await readJson(context));
  if (!parsed.success) {
    return fail(context, 400, "invalid_request", "Check the data you sent.");
  }

  const user = context.get("user");
  const since = parsed.data.since ?? "1970-01-01T00:00:00.000Z";
  const statements: D1PreparedStatement[] = [];

  for (const row of parsed.data.prayers) {
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO prayers (uuid, user_id, title, status, created_at, answered_at, testimony, updated_at, deleted_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(uuid) DO UPDATE SET
           title = excluded.title,
           status = excluded.status,
           created_at = excluded.created_at,
           answered_at = excluded.answered_at,
           testimony = excluded.testimony,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at
         WHERE excluded.updated_at > prayers.updated_at AND prayers.user_id = excluded.user_id`,
      ).bind(
        row.uuid,
        user.id,
        row.title,
        row.status,
        row.createdAt,
        row.answeredAt ?? null,
        row.testimony ?? null,
        row.updatedAt,
        row.deletedAt ?? null,
      ),
    );
  }

  for (const row of parsed.data.thanks) {
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO thanks (uuid, user_id, text, day, updated_at, deleted_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(uuid) DO UPDATE SET
           text = excluded.text,
           day = excluded.day,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at
         WHERE excluded.updated_at > thanks.updated_at AND thanks.user_id = excluded.user_id`,
      ).bind(row.uuid, user.id, row.text, row.day, row.updatedAt, row.deletedAt ?? null),
    );
  }

  for (const row of parsed.data.entries) {
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO entries (uuid, user_id, kind, text, decision, created_at, updated_at, deleted_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(uuid) DO UPDATE SET
           kind = excluded.kind,
           text = excluded.text,
           decision = excluded.decision,
           created_at = excluded.created_at,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at
         WHERE excluded.updated_at > entries.updated_at AND entries.user_id = excluded.user_id`,
      ).bind(
        row.uuid,
        user.id,
        row.kind,
        row.text,
        row.decision ?? null,
        row.createdAt,
        row.updatedAt,
        row.deletedAt ?? null,
      ),
    );
  }

  if (statements.length > 0) {
    await context.env.DB.batch(statements);
  }

  const changes = await pull(context.env, user.id, since);
  return context.json({ serverTime: new Date().toISOString(), ...changes });
});

sync.get("/", async (context) => {
  const since = context.req.query("since") ?? "1970-01-01T00:00:00.000Z";
  const user = context.get("user");
  const changes = await pull(context.env, user.id, since);
  return context.json({ serverTime: new Date().toISOString(), ...changes });
});

