#!/usr/bin/env bash
#
# rebuild_dev_toolbox.sh – resets the Fedora-based "dev" toolbox
# and re-applies all chezmoi-managed config and packages.

set -euo pipefail

# ---- Config ----
TOOLBOX_NAME="dev"
FEDORA_VERSION="42"

# ---- Destroy existing toolbox ----
echo "🔥 Destroying existing '$TOOLBOX_NAME' toolbox (if it exists)..."
toolbox rm -f "$TOOLBOX_NAME" 2>/dev/null || true

# ---- Create fresh toolbox ----
echo "📦 Creating a fresh '$TOOLBOX_NAME' toolbox for Fedora $FEDORA_VERSION..."
toolbox create --container "$TOOLBOX_NAME" --distro fedora --release "$FEDORA_VERSION"

echo "🚀 Starting the new container..."
toolbox enter "$TOOLBOX_NAME" bash -c 'exit'

# ---- Run chezmoi inside the toolbox ----
echo "🛠️  Configuring container as user '$(whoami)' via chezmoi..."
toolbox run -c "$TOOLBOX_NAME" bash -c '
  sudo rm -rf ~/.config/chezmoi
  sudo rm -rf ~/.local/share/chezmoi
  sudo rm -rf ~/.cache/chezmoi
  git config --global --add safe.directory /src || true
  curl -sfL https://git.io/chezmoi | bash -s -- -b ~/.local/bin
  exec ~/.local/bin/chezmoi init --apply --verbose
'

echo "🎉  Environment bootstrap complete."
echo "✅ All done! Your '$TOOLBOX_NAME' (Fedora $FEDORA_VERSION) toolbox has been rebuilt."
echo "Run 'toolbox enter $TOOLBOX_NAME' to get started."
