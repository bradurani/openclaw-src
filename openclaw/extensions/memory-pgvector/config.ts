export type MemoryPgvectorConfig = {
  connectionString: string;
  tableName: string;
  embedding: {
    provider: "openai";
    model: string;
    apiKey: string;
  };
  autoCapture: boolean;
  autoRecall: boolean;
  captureMaxChars: number;
};

export const MEMORY_CATEGORIES = ["preference", "fact", "decision", "entity", "other"] as const;
export type MemoryCategory = (typeof MEMORY_CATEGORIES)[number];

const DEFAULT_MODEL = "text-embedding-3-small";
const DEFAULT_TABLE_NAME = "memories";
export const DEFAULT_CAPTURE_MAX_CHARS = 500;

const EMBEDDING_DIMENSIONS: Record<string, number> = {
  "text-embedding-3-small": 1536,
  "text-embedding-3-large": 3072,
};

export function vectorDimsForModel(model: string): number {
  const dims = EMBEDDING_DIMENSIONS[model];
  if (!dims) {
    throw new Error(`Unsupported embedding model: ${model}`);
  }
  return dims;
}

function resolveEnvVars(value: string): string {
  return value.replace(/\$\{([^}]+)\}/g, (_, envVar) => {
    const envValue = process.env[envVar];
    if (!envValue) {
      throw new Error(`Environment variable ${envVar} is not set`);
    }
    return envValue;
  });
}

function assertAllowedKeys(value: Record<string, unknown>, allowed: string[], label: string) {
  const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) {
    throw new Error(`${label} has unknown keys: ${unknown.join(", ")}`);
  }
}

export const memoryPgvectorConfigSchema = {
  parse(value: unknown): MemoryPgvectorConfig {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("memory-pgvector config required");
    }
    const cfg = value as Record<string, unknown>;
    assertAllowedKeys(
      cfg,
      ["connectionString", "tableName", "embedding", "autoCapture", "autoRecall", "captureMaxChars"],
      "memory-pgvector config",
    );

    if (typeof cfg.connectionString !== "string" || !cfg.connectionString) {
      throw new Error("connectionString is required");
    }

    const embedding = cfg.embedding as Record<string, unknown> | undefined;
    if (!embedding || typeof embedding.apiKey !== "string") {
      throw new Error("embedding.apiKey is required");
    }
    assertAllowedKeys(embedding, ["apiKey", "model"], "embedding config");

    const model = typeof embedding.model === "string" ? embedding.model : DEFAULT_MODEL;
    vectorDimsForModel(model);

    const tableName = typeof cfg.tableName === "string" ? cfg.tableName : DEFAULT_TABLE_NAME;

    const captureMaxChars =
      typeof cfg.captureMaxChars === "number" ? Math.floor(cfg.captureMaxChars) : undefined;
    if (
      typeof captureMaxChars === "number" &&
      (captureMaxChars < 100 || captureMaxChars > 10_000)
    ) {
      throw new Error("captureMaxChars must be between 100 and 10000");
    }

    return {
      connectionString: resolveEnvVars(cfg.connectionString as string),
      tableName,
      embedding: {
        provider: "openai",
        model,
        apiKey: resolveEnvVars(embedding.apiKey),
      },
      autoCapture: cfg.autoCapture === true,
      autoRecall: cfg.autoRecall !== false,
      captureMaxChars: captureMaxChars ?? DEFAULT_CAPTURE_MAX_CHARS,
    };
  },
};
