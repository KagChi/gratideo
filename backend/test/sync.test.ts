import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

const BASE = "https://gratideo.test";
const VERIFIER = "dGhpcy1pcy1hLXRlc3QtdmVyaWZpZXItNDQtY2hhcnM=";

let counter = 0;
function uniqueEmail(): string {
  counter += 1;
  return `sync${counter}.${Date.now()}@example.com`;
}

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
    email: uniqueEmail(),
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
    const response = await post("/v1/sync", { prayers: [prayer("prayer-1")], thanks: [], entries: [] }, token);
    expect(response.status).toBe(200);
    const body = (await response.json()) as any;
    expect(body.prayers).toHaveLength(1);
    expect(body.prayers[0].title).toBe("Wisdom for the team");
    expect(body.prayers[0].deletedAt).toBeNull();
    expect(typeof body.serverTime).toBe("string");
  });

  it("gives another device the rows changed since its cursor", async () => {
    const token = await account();
    await post("/v1/sync", { prayers: [prayer("prayer-1")], thanks: [], entries: [] }, token);

    const first = (await (await SELF.fetch(BASE + "/v1/sync?since=1970-01-01T00:00:00.000Z", {
      headers: { authorization: `Bearer ${token}`, "cf-connecting-ip": "198.51.100.201" },
    })).json()) as any;
    const cursor = first.serverTime;

    const second = await SELF.fetch(BASE + `/v1/sync?since=${encodeURIComponent(cursor)}`, {
      headers: { authorization: `Bearer ${token}`, "cf-connecting-ip": "198.51.100.202" },
    });
    const body = (await second.json()) as any;
    expect(body.prayers).toHaveLength(0);
  });

  it("keeps the newest version when an older edit arrives late", async () => {
    const token = await account();
    await post("/v1/sync", { prayers: [prayer("prayer-2", { title: "Newer" })] }, token);
    const response = await post(
      "/v1/sync",
      { prayers: [prayer("prayer-2", { title: "Older", updatedAt: "2026-01-01T00:00:00.000Z" })] },
      token,
    );
    const body = (await response.json()) as any;
    expect(body.prayers).toHaveLength(1);
    expect(body.prayers[0].title).toBe("Newer");
  });

  it("propagates deletions as tombstones", async () => {
    const token = await account();
    await post("/v1/sync", { prayers: [prayer("prayer-3")] }, token);
    const response = await post(
      "/v1/sync",
      { prayers: [prayer("prayer-3", { updatedAt: "2026-03-01T00:00:00.000Z", deletedAt: "2026-03-01T00:00:00.000Z" })] },
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
        thanks: [{ uuid: "thanks-1", text: "Rain", day: "2026-02-01", updatedAt: "2026-02-01T07:00:00.000Z", deletedAt: null }],
        entries: [
          {
            uuid: "entry-0001",
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
    await post("/v1/sync", { prayers: [prayer("prayer-4")] }, mine);

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

