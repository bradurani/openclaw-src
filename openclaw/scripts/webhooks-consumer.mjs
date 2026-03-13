import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from "@aws-sdk/client-sqs";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const REGION = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "us-west-2";
const SQS_URL = process.env.WEBHOOKS_SQS_URL;
const GATEWAY_HOOKS_URL = process.env.GATEWAY_HOOKS_URL;
const HOOKS_TOKEN_SECRET_ID = process.env.HOOKS_TOKEN_SECRET_ID || "openclaw/hooks-token";

if (!SQS_URL) {
  console.error("[webhooks-consumer] missing WEBHOOKS_SQS_URL");
  process.exit(1);
}
if (!GATEWAY_HOOKS_URL) {
  console.error("[webhooks-consumer] missing GATEWAY_HOOKS_URL");
  process.exit(1);
}

const sqs = new SQSClient({ region: REGION });
const sm = new SecretsManagerClient({ region: REGION });

let cachedToken = null;
let cachedAt = 0;
async function getToken() {
  const now = Date.now();
  if (cachedToken && now - cachedAt < 5 * 60_000) return cachedToken; // 5 min
  const resp = await sm.send(new GetSecretValueCommand({ SecretId: HOOKS_TOKEN_SECRET_ID }));
  cachedToken = resp.SecretString;
  cachedAt = now;
  return cachedToken;
}

async function postHook(payload) {
  const token = await getToken();
  const r = await fetch(GATEWAY_HOOKS_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "authorization": `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });

  const text = await r.text();
  if (!r.ok) {
    throw new Error(`gateway hook POST failed: ${r.status} ${r.statusText}: ${text.slice(0, 500)}`);
  }
  return text;
}

function sleep(ms) {
  return new Promise((res) => setTimeout(res, ms));
}

console.log(`[webhooks-consumer] starting region=${REGION} sqs=${SQS_URL} url=${GATEWAY_HOOKS_URL}`);

let backoffMs = 250;
for (;;) {
  try {
    const resp = await sqs.send(
      new ReceiveMessageCommand({
        QueueUrl: SQS_URL,
        MaxNumberOfMessages: 5,
        WaitTimeSeconds: 20,
        VisibilityTimeout: 30,
      })
    );

    const msgs = resp.Messages || [];
    if (msgs.length === 0) {
      backoffMs = 250;
      continue;
    }

    for (const m of msgs) {
      let payload;
      try {
        payload = JSON.parse(m.Body || "{}");
      } catch {
        payload = { raw: m.Body };
      }

      await postHook(payload);

      await sqs.send(
        new DeleteMessageCommand({
          QueueUrl: SQS_URL,
          ReceiptHandle: m.ReceiptHandle,
        })
      );
    }

    backoffMs = 250;
  } catch (err) {
    console.error("[webhooks-consumer] error", err?.stack || String(err));
    await sleep(backoffMs);
    backoffMs = Math.min(backoffMs * 2, 10_000);
  }
}
