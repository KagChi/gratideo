export {};

declare global {
  namespace Cloudflare {
    interface Env {
      DB: D1Database;
      PEPPER: string;
      AUTH_RATE_LIMITER?: {
        limit(options: { key: string }): Promise<{ success: boolean }>;
      };
      TEST_MIGRATIONS: { name: string; queries: string[] }[];
    }
  }
}

