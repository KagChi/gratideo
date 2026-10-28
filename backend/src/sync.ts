import { Hono } from "hono";
import { z } from "zod";

import { requireUser } from "./session";
import type { AppEnv } from "./types";
import { fail, readJson } from "./types";

const timestamp = z.string().min(10).max(40);
const maybeTimestamp = timestamp.nullable().optional();
const uuid = z.string().min(8).max(64);
const MAX_ROWS = 200;
const PULL_LIMIT = 2000;

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

const prayerColumns = `uuid, title, status, created_at AS createdAt, answered_at AS answeredAt,
  testimony, updated_at AS updatedAt, deleted_at AS deletedAt, synced_at AS syncedAt`;
const thanksColumns = "uuid, text, day, updated_at AS updatedAt, deleted_at AS deletedAt, synced_at AS syncedAt";
const entryColumns = `uuid, kind, text, decision, created_at AS createdAt,
  updated_at AS updatedAt, deleted_at AS deletedAt, synced_at AS syncedAt`;

interface PulledRow {
  syncedAt?: string;
}

async function pull(env: AppEnv["Bindings"], userId: string, since: string) {
  const [prayers, thanks, entries] = await Promise.all([
    env.DB.prepare(
      `SELECT ${prayerColumns} FROM prayers WHERE user_id = ? AND synced_at > ? ORDER BY synced_at LIMIT ${PULL_LIMIT}`,
    )
      .bind(userId, since)
      .all<PulledRow>(),
    env.DB.prepare(
      `SELECT ${thanksColumns} FROM thanks WHERE user_id = ? AND synced_at > ? ORDER BY synced_at LIMIT ${PULL_LIMIT}`,
    )
      .bind(userId, since)
      .all<PulledRow>(),
    env.DB.prepare(
      `SELECT ${entryColumns} FROM entries WHERE user_id = ? AND synced_at > ? ORDER BY synced_at LIMIT ${PULL_LIMIT}`,
    )
      .bind(userId, since)
      .all<PulledRow>(),
  ]);

  const lists = [prayers.results ?? [], thanks.results ?? [], entries.results ?? []];
  let cursor = since;
  for (const list of lists) {
    for (const row of list) {
      const stamp = row.syncedAt;
      if (stamp && stamp > cursor) cursor = stamp;
    }
  }

  return {
    serverTime: cursor,
    prayers: lists[0],
    thanks: lists[1],
    entries: lists[2],
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
  const now = new Date().toISOString();
  const statements: D1PreparedStatement[] = [];

  for (const row of parsed.data.prayers) {
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO prayers (uuid, user_id, title, status, created_at, answered_at, testimony, updated_at, deleted_at, synced_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(uuid) DO UPDATE SET
           title = excluded.title,
           status = excluded.status,
           created_at = excluded.created_at,
           answered_at = excluded.answered_at,
           testimony = excluded.testimony,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at,
           synced_at = excluded.synced_at
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
        now,
      ),
    );
  }

  for (const row of parsed.data.thanks) {
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO thanks (uuid, user_id, text, day, updated_at, deleted_at, synced_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(uuid) DO UPDATE SET
           text = excluded.text,
           day = excluded.day,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at,
           synced_at = excluded.synced_at
         WHERE excluded.updated_at > thanks.updated_at AND thanks.user_id = excluded.user_id`,
      ).bind(row.uuid, user.id, row.text, row.day, row.updatedAt, row.deletedAt ?? null, now),
    );
  }

  for (const row of parsed.data.entries) {
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO entries (uuid, user_id, kind, text, decision, created_at, updated_at, deleted_at, synced_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(uuid) DO UPDATE SET
           kind = excluded.kind,
           text = excluded.text,
           decision = excluded.decision,
           created_at = excluded.created_at,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at,
           synced_at = excluded.synced_at
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
        now,
      ),
    );
  }

  if (statements.length > 0) {
    await context.env.DB.batch(statements);
  }

  return context.json(await pull(context.env, user.id, since));
});

sync.get("/", async (context) => {
  const since = context.req.query("since") ?? "1970-01-01T00:00:00.000Z";
  const user = context.get("user");
  return context.json(await pull(context.env, user.id, since));
});

