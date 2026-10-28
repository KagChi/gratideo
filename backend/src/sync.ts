import { Hono } from "hono";
import { z } from "zod";

import { requireUser } from "./session";
import type { AppEnv } from "./types";
import { fail, readJson } from "./types";

const timestamp = z.string().min(10).max(40);
const maybeTimestamp = timestamp.nullable().optional();
const uuid = z.string().min(8).max(64);

const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 200;
const EPOCH = "1970-01-01T00:00:00.000Z";

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

const cursorsSchema = z
  .object({
    prayers: z.string().max(200).optional(),
    thanks: z.string().max(200).optional(),
    entries: z.string().max(200).optional(),
  })
  .partial()
  .optional();

const pushSchema = z.object({
  since: maybeTimestamp,
  cursors: cursorsSchema,
  pageSize: z.number().int().min(1).max(MAX_PAGE_SIZE).optional(),
  prayers: z.array(prayerSchema).max(MAX_PAGE_SIZE).default([]),
  thanks: z.array(thanksSchema).max(MAX_PAGE_SIZE).default([]),
  entries: z.array(entrySchema).max(MAX_PAGE_SIZE).default([]),
});

const tables = {
  prayers: {
    columns: `uuid, title, status, created_at AS createdAt, answered_at AS answeredAt,
      testimony, updated_at AS updatedAt, deleted_at AS deletedAt, synced_at AS syncedAt`,
  },
  thanks: {
    columns: "uuid, text, day, updated_at AS updatedAt, deleted_at AS deletedAt, synced_at AS syncedAt",
  },
  entries: {
    columns: `uuid, kind, text, decision, created_at AS createdAt,
      updated_at AS updatedAt, deleted_at AS deletedAt, synced_at AS syncedAt`,
  },
} as const;

type TableName = keyof typeof tables;
type Cursor = { syncedAt: string; uuid: string };

function encodeCursor(cursor: Cursor): string {
  return btoa(`${cursor.syncedAt}|${cursor.uuid}`)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function decodeCursor(value: string | undefined, fallback: Cursor): Cursor | null {
  if (!value) return fallback;
  try {
    const padded = value.replace(/-/g, "+").replace(/_/g, "/");
    const raw = atob(padded + "=".repeat((4 - (padded.length % 4)) % 4));
    const separator = raw.indexOf("|");
    if (separator < 0) return null;
    return { syncedAt: raw.slice(0, separator), uuid: raw.slice(separator + 1) };
  } catch {
    return null;
  }
}

async function page(
  env: AppEnv["Bindings"],
  table: TableName,
  userId: string,
  cursor: Cursor,
  limit: number,
) {
  const { columns } = tables[table];
  const result = await env.DB.prepare(
    `SELECT ${columns} FROM ${table}
      WHERE user_id = ? AND (synced_at > ? OR (synced_at = ? AND uuid > ?))
      ORDER BY synced_at, uuid
      LIMIT ${limit + 1}`,
  )
    .bind(userId, cursor.syncedAt, cursor.syncedAt, cursor.uuid)
    .all<Record<string, unknown> & { uuid: string }>();

  const rows = result.results ?? [];
  const hasMore = rows.length > limit;
  const pageRows = hasMore ? rows.slice(0, limit) : rows;
  const last = pageRows[pageRows.length - 1];
  const next = last
    ? { syncedAt: (last.syncedAt as string) ?? cursor.syncedAt, uuid: last.uuid }
    : cursor;
  return { rows: pageRows, next, hasMore };
}

async function pull(
  env: AppEnv["Bindings"],
  userId: string,
  input: { cursors?: Record<string, string | undefined>; since?: string | null; pageSize?: number },
) {
  const limit = input.pageSize ?? DEFAULT_PAGE_SIZE;
  const incoming: Record<TableName, string | undefined> = {
    prayers: input.cursors?.prayers,
    thanks: input.cursors?.thanks,
    entries: input.cursors?.entries,
  };

  const decoded: Record<TableName, Cursor> = {
    prayers: { syncedAt: input.since ?? EPOCH, uuid: "" },
    thanks: { syncedAt: input.since ?? EPOCH, uuid: "" },
    entries: { syncedAt: input.since ?? EPOCH, uuid: "" },
  };

  for (const table of Object.keys(tables) as TableName[]) {
    const parsed = decodeCursor(incoming[table], decoded[table]);
    if (!parsed) return null;
    decoded[table] = parsed;
  }

  const [prayers, thanks, entries] = await Promise.all([
    page(env, "prayers", userId, decoded.prayers, limit),
    page(env, "thanks", userId, decoded.thanks, limit),
    page(env, "entries", userId, decoded.entries, limit),
  ]);

  return {
    prayers: prayers.rows,
    thanks: thanks.rows,
    entries: entries.rows,
    cursors: {
      prayers: encodeCursor(prayers.next),
      thanks: encodeCursor(thanks.next),
      entries: encodeCursor(entries.next),
    },
    hasMore: prayers.hasMore || thanks.hasMore || entries.hasMore,
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

  const changes = await pull(context.env, user.id, {
    cursors: parsed.data.cursors,
    since: parsed.data.since,
    pageSize: parsed.data.pageSize,
  });
  if (!changes) return fail(context, 400, "invalid_request", "That cursor is not valid.");
  return context.json(changes);
});

sync.get("/", async (context) => {
  const user = context.get("user");
  const changes = await pull(context.env, user.id, {
    since: context.req.query("since") ?? EPOCH,
    pageSize: Number(context.req.query("pageSize") ?? DEFAULT_PAGE_SIZE),
  });
  if (!changes) return fail(context, 400, "invalid_request", "That cursor is not valid.");
  return context.json(changes);
});

