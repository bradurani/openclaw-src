#!/usr/bin/env bash

set -euo pipefail

# Approve pending OpenClaw DM pairing requests via ECS Exec.
# Prompts for each request; never auto-approves.

usage() {
  cat <<'USAGE'
Usage:
  script/approve-pairings.sh <channel> [channel...]

Options:
  --cluster <name>    ECS cluster (default: openclaw)
  --service <name>    ECS service (default: openclaw)
  --container <name>  ECS container (default: openclaw)
  --task <arn>        конкретная задача ECS (optional)
  --region <region>   AWS region (default: us-west-2)
  --state-dir <path>  Override OpenClaw state dir (default: ~/.openclaw)
  --debug             Print debug info from inside the container

Examples:
  script/approve-pairings.sh telegram
  script/approve-pairings.sh discord slack --cluster openclaw --service openclaw
USAGE
}

CLUSTER="openclaw"
SERVICE="openclaw"
CONTAINER="openclaw"
REGION="us-west-2"
TASK_ARN=""
STATE_DIR="~/.openclaw"
DEBUG="false"
CHANNELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --container) CONTAINER="$2"; shift 2 ;;
    --task) TASK_ARN="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    --debug) DEBUG="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "Unknown option: $1"; usage; exit 1 ;;
    *) CHANNELS+=("$1"); shift ;;
  esac
 done

resolve_task() {
  if [[ -n "$TASK_ARN" ]]; then
    echo "$TASK_ARN"
    return
  fi

  local task
  task=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --service-name "$SERVICE" \
    --desired-status RUNNING \
    --region "$REGION" \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || true)

  if [[ -z "$task" || "$task" == "None" || "$task" == "null" ]]; then
    echo "No running tasks found for $CLUSTER/$SERVICE" >&2
    exit 1
  fi
  echo "$task"
}

TASK_ARN="$(resolve_task)"

exec_cmd() {
  local cmd="$1"
  aws ecs execute-command \
    --cluster "$CLUSTER" \
    --task "$TASK_ARN" \
    --container "$CONTAINER" \
    --interactive \
    --region "$REGION" \
    --command "bash -lc '$cmd'" 2>&1
}

discover_channels() {
  local out
  local cred_dir="${STATE_DIR%/}/credentials"
  out=$(exec_cmd "ls -1 $cred_dir/*-pairing.json 2>/dev/null" || true)
  printf "%s" "$out" | python3 - <<'PY'
import re,sys,os
text=sys.stdin.read()
paths=re.findall(r'(/[^ \n]+-pairing\.json)', text)
channels=[]
for p in paths:
    base=os.path.basename(p)
    if base.endswith("-pairing.json"):
        channels.append(base[:-len("-pairing.json")])
print(" ".join(sorted(set(channels))))
PY
}

if [[ ${#CHANNELS[@]} -eq 0 ]]; then
  discovered=$(discover_channels)
  if [[ -z "$discovered" ]]; then
    echo "No channels specified and no pending pairing files found under ${STATE_DIR%/}/credentials." >&2
    exit 1
  fi
  read -r -a CHANNELS <<<"$discovered"
  echo "Discovered channels with pending pairing files: ${CHANNELS[*]}"
fi

extract_json() {
  python3 - <<'PY'
import json,sys
text=sys.stdin.read()
# Find first JSON object/array in output
start=min([i for i in [text.find('{'), text.find('[')] if i!=-1] or [-1])
if start==-1:
    sys.exit(1)
frag=text[start:]
# Try to parse progressively by trimming trailing junk
for end in range(len(frag), 0, -1):
    try:
        json.loads(frag[:end])
        print(frag[:end])
        sys.exit(0)
    except Exception:
        continue
sys.exit(1)
PY
}

pick_code() {
  python3 - <<'PY'
import json,sys
item=json.load(sys.stdin)
for key in ["code","pairingCode","pairCode","token","requestId","id"]:
    if key in item and item[key]:
        print(str(item[key]))
        sys.exit(0)
print("")
PY
}

for channel in "${CHANNELS[@]}"; do
  echo "\n== Channel: $channel =="

  if [[ "$DEBUG" == "true" ]]; then
    exec_cmd "ls -la ${STATE_DIR%/} ${STATE_DIR%/}/credentials 2>/dev/null || true"
  fi

  out=$(exec_cmd "openclaw pairing list $channel --json" || true)

  json_out=$(printf "%s" "$out" | extract_json || true)
  if [[ -z "$json_out" ]]; then
    echo "Could not parse JSON from output. Raw output:" >&2
    echo "$out"
    continue
  fi

  count=$(printf "%s" "$json_out" | python3 - <<'PY'
import json,sys
j=json.load(sys.stdin)
print(len(j) if isinstance(j,list) else 0)
PY
  )

  if [[ "$count" == "0" ]]; then
    echo "No pending pairing requests."
    continue
  fi

  printf "%s" "$json_out" | python3 - <<'PY'
import json,sys
j=json.load(sys.stdin)
for i,item in enumerate(j,1):
    summary={k:item.get(k) for k in ("code","pairingCode","pairCode","sender","userId","name","createdAt","channel") if k in item}
    print(f"[{i}] {summary if summary else item}")
PY

  # Iterate entries for approval
  for idx in $(seq 1 "$count"); do
    item_json=$(printf "%s" "$json_out" | python3 - <<PY
import json,sys
j=json.load(sys.stdin)
idx=int("$idx")-1
print(json.dumps(j[idx]))
PY
    )

    code=$(printf "%s" "$item_json" | pick_code)

    if [[ -z "$code" ]]; then
      echo "Request #$idx has no obvious code/id. Skipping." >&2
      continue
    fi

    read -r -p "Approve pairing request #$idx (code: $code) for $channel? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      echo "Approving $channel $code..."
      exec_cmd "openclaw pairing approve $channel $code" || true
    else
      echo "Skipped."
    fi
  done
 done
