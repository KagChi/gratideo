import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

const BASE = "https://gratideo.test";
const VERIFIER = "dGhpcy1pcy1hLXRlc3QtdmVyaWZpZXItNDQtY2hhcnM=";

let counter = 0;
const nextId = (prefix: string) => `${prefix}-${++counter}-${Date.now()}`;

async function post(path: string, body: unknown, token?: string): Promise<Response> {
  return SELF.fetch(BASE + path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "cf-connecting-ip": "198.51.100.200",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function account(): Promise<string> {
  const response = await post("/v1/auth/register", {
    name: "Sync User",
    email: `sync.${++counter}.${Date.now()}@example.com`,
    verifier: VERIFIER,
  });
  const body = (await response.json()) as { token: string };
  return body.token;
}

function prayer(uuid: string, overrides: Record<string, unknown> = {}) {
  return {
    uuid,
    title: "Wisdom for the team",
    status: "praying",
    createdAt: "2026-02-01T06:00:00.000Z",
    answeredAt: null,
    testimony: null,
    updatedAt: "2026-02-01T06:00:00.000Z",
    deletedAt: null,
    ...overrides,
  };
}

describe("sync", () => {
  it("pushes a prayer and returns it in the same round trip", async () => {
    const token = await account();
    const response = await post("/v1/sync", { prayers: [prayer(nextId("prayer"))], thanks: [], entries: [] }, token);
    expect(response.status).toBe(200);
    const body = (await response.json()) as any;
    expect(body.prayers).toHaveLength(1);
    expect(body.prayers[0].title).toBe("Wisdom for the team");
    expect(body.prayers[0].deletedAt).toBeNull();
    expect(typeof body.cursors.prayers).toBe("string");
    expect(body.hasMore).toBe(false);
  });

  it("gives another device the rows changed since its cursor", async () => {
    const token = await account();
    await post("/v1/sync", { prayers: [prayer(nextId("prayer"))], thanks: [], entries: [] }, token);

    const first = (await (await post("/v1/sync", {}, token)).json()) as any;
    expect(first.prayers).toHaveLength(1);

    const second = (await (await post("/v1/sync", { cursors: first.cursors }, token)).json()) as any;
    expect(second.prayers).toHaveLength(0);
  });

  it("pages through changes with a cursor instead of sending everything", async () => {
    const token = await account();
    const rows = Array.from({ length: 5 }, (_, index) =>
      prayer(nextId("page"), { updatedAt: `2026-04-0${index + 1}T00:00:00.000Z` }),
    );
    await post("/v1/sync", { prayers: rows }, token);

    const seen: string[] = [];
    let cursors: Record<string, string> = {};
    let pages = 0;
    let hasMore = true;
    while (hasMore && pages < 10) {
      const response = await post("/v1/sync", { cursors, pageSize: 2 }, token);
      const body = (await response.json()) as any;
      expect(body.prayers.length).toBeLessThanOrEqual(2);
      seen.push(...body.prayers.map((row: { uuid: string }) => row.uuid));
      cursors = body.cursors;
      hasMore = body.hasMore;
      pages += 1;
    }

    expect(pages).toBeGreaterThan(1);
    expect(seen).toHaveLength(5);
    expect(new Set(seen).size).toBe(5);
  });

  it("rejects a cursor it cannot read", async () => {
    const token = await account();
    const response = await post("/v1/sync", { cursors: { prayers: "not-a-cursor" } }, token);
    expect(response.status).toBe(400);
  });

  it("keeps the newest version when an older edit arrives late", async () => {
    const token = await account();
    const id = nextId("prayer");
    await post("/v1/sync", { prayers: [prayer(id, { title: "Newer" })] }, token);
    const response = await post(
      "/v1/sync",
      { prayers: [prayer(id, { title: "Older", updatedAt: "2026-01-01T00:00:00.000Z" })] },
      token,
    );
    const body = (await response.json()) as any;
    expect(body.prayers).toHaveLength(1);
    expect(body.prayers[0].title).toBe("Newer");
  });

  it("propagates deletions as tombstones", async () => {
    const token = await account();
    const id = nextId("prayer");
    await post("/v1/sync", { prayers: [prayer(id)] }, token);
    const response = await post(
      "/v1/sync",
      { prayers: [prayer(id, { updatedAt: "2026-03-01T00:00:00.000Z", deletedAt: "2026-03-01T00:00:00.000Z" })] },
      token,
    );
    const body = (await response.json()) as any;
    expect(body.prayers[0].deletedAt).toBe("2026-03-01T00:00:00.000Z");
  });

  it("syncs thanks and journal entries too", async () => {
    const token = await account();
    const response = await post(
      "/v1/sync",
      {
        thanks: [
          { uuid: nextId("thanks"), text: "Rain", day: "2026-02-01", updatedAt: "2026-02-01T07:00:00.000Z", deletedAt: null },
        ],
        entries: [
          {
            uuid: nextId("entry"),
            kind: "journal",
            text: "A quiet morning.",
            decision: null,
            createdAt: "2026-02-01T07:05:00.000Z",
            updatedAt: "2026-02-01T07:05:00.000Z",
            deletedAt: null,
          },
        ],
      },
      token,
    );
    const body = (await response.json()) as any;
    expect(body.thanks).toHaveLength(1);
    expect(body.thanks[0].day).toBe("2026-02-01");
    expect(body.entries).toHaveLength(1);
    expect(body.entries[0].kind).toBe("journal");
  });

  it("never shows one account the data of another", async () => {
    const mine = await account();
    const other = await account();
    await post("/v1/sync", { prayers: [prayer(nextId("prayer"))] }, mine);

    const response = await SELF.fetch(BASE + "/v1/sync", {
      headers: { authorization: `Bearer ${other}`, "cf-connecting-ip": "198.51.100.203" },
    });
    const body = (await response.json()) as any;
    expect(body.prayers).toHaveLength(0);
  });

  it("needs a session", async () => {
    const response = await SELF.fetch(BASE + "/v1/sync", { headers: { "cf-connecting-ip": "198.51.100.204" } });
    expect(response.status).toBe(401);
  });

  it("rejects malformed rows", async () => {
    const token = await account();
    const response = await post("/v1/sync", { prayers: [{ uuid: "x" }] }, token);
    expect(response.status).toBe(400);
  });
});

