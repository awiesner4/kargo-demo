#!/usr/bin/env bash
set -euo pipefail

#
# install-keychain-plugin.sh (corrected)
#
# Installs the KeychainSecretGenerator plugin under:
#   ~/.config/kustomize/plugin/example.com/v1/KeychainSecretGenerator/KeychainSecretGenerator
#
# This version fixes the here‐doc so you won’t see “EOF: command not found.”
#
# Usage:
#   chmod +x install-keychain-plugin.sh
#   ./install-keychain-plugin.sh
#

PLUGIN_DIR="${HOME}/.config/kustomize/plugin/example.com/v1/KeychainSecretGenerator"

echo "▶️  Creating plugin directory at:"
echo "    $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"

cat << 'PLUGIN_SCRIPT_EOF' > "$PLUGIN_DIR/KeychainSecretGenerator"
#!/usr/bin/env bash
set -euo pipefail

#
# KeychainSecretGenerator (updated)
#
# Invoked by Kustomize for:
#   apiVersion: example.com/v1
#   kind: KeychainSecretGenerator
#
# Accepts either:
#   • A single argument that is a path to the marker YAML file, or
#   • The marker YAML piped via stdin.
#
# Required top‐level keys in the marker YAML:
#   service:    (macOS Keychain “service”)
#   account:    (macOS Keychain “account”)
#   name:       (Kubernetes Secret name)
#   repoURL:    (the Git repository URL)
#   username:   (the Git username)
# Optional key:
#   namespace:  (Kubernetes namespace)
#
# Runs:
#   security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w
#
# Emits a ResourceList with one Secret containing:
#   stringData:
#     repoURL:  "<repoURL>"
#     username: "<username>"
#     password: "<Keychain password>"

# 1) Load marker YAML into a variable (from file or stdin)
if [[ $# -ge 1 && -f "$1" && -r "$1" ]]; then
  INPUT="$(cat "$1")"
else
  INPUT="$(cat <&0)"
fi

# 2) Helper to extract a top-level field from INPUT
extract_field() {
  local key="$1"
  echo "$INPUT" \
    | grep -E "^[[:space:]]*${key}:" \
    | head -n1 \
    | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//; s/[[:space:]]*$//"
}

SERVICE="$(extract_field service)"
ACCOUNT="$(extract_field account)"

# For top‐level “name:”, pick the last occurrence (skip metadata.name)
SECRET_NAME="$(echo "$INPUT" \
  | grep -E '^[[:space:]]*name:' \
  | tail -n1 \
  | sed -E 's/^[[:space:]]*name:[[:space:]]*//; s/[[:space:]]*$//')"

REPO_URL="$(extract_field repoURL)"
USERNAME="$(extract_field username)"
NAMESPACE="$(extract_field namespace)"

# 3) Validate required fields
if [[ -z "$SERVICE" || -z "$ACCOUNT" || -z "$SECRET_NAME" || -z "$REPO_URL" || -z "$USERNAME" ]]; then
  echo "ERROR: 'service', 'account', top‐level 'name', 'repoURL', and 'username' must be set in marker YAML." >&2
  exit 1
fi

# 4) Fetch password from macOS Keychain (may prompt Touch ID)
PASSWORD="$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w)"

# 5) Emit a ResourceList with one Secret containing repoURL, username, and password
cat <<EOF
apiVersion: v1
kind: ResourceList
items:
- apiVersion: v1
  kind: Secret
  metadata:
    name: ${SECRET_NAME}
    $( [[ -n "$NAMESPACE" ]] && echo "namespace: ${NAMESPACE}" )
    labels:
      kargo.akuity.io/cred-type: git
  type: Opaque
  stringData:
    repoURL:  "${REPO_URL}"
    username: "${USERNAME}"
    password: "${PASSWORD}"
EOF
PLUGIN_SCRIPT_EOF

chmod +x "$PLUGIN_DIR/KeychainSecretGenerator"
echo "✅  Installed KeychainSecretGenerator plugin to:"
echo "    $PLUGIN_DIR/KeychainSecretGenerator"
