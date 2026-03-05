#!/bin/sh
# 002-catch-all-secretrefs.sh — NO-OP (superseded by env var approach)
#
# Originally this patch converted ${VAR} strings to SecretRef objects.
# Now all secrets are resolved via env vars in the wrapper script instead,
# because the exec provider can't find the `aws` CLI on the node PATH.
#
# This patch is kept as a no-op since it's already been applied on EFS
# and the patches-applied tracking prevents re-running it.

set -e

echo "  patch 002: no-op (superseded by env var approach)"
