#!/bin/bash
#
# rebuild_dev_toolbox.sh
#
# Rebuilds the 'dev' toolbox without trying to run Podman inside it.
# Should be run from the host. Avoids Podman namespace hangs.
# Destroys and rebuilds the 'dev' toolbox for a specific Fedora release,
# leveraging chezmoi as the single source of truth for setup.
# It should be run from the host (Bluefin).
#
# WARNING: This is a destructive operation.

set -e

# --- Configuration ---
TOOLBOX_NAME="dev"
FEDORA_RELEASE="42"
DOTFILES_REPO="https://github.com/jamespetran/dotfiles.git"

# --- Spinner Utility ---
run_with_spinner() {
  local MSG="$1"
  shift
  local CMD=("$@")
  local PID
  local SPINNER=("|" "/" "-" "\\")
  local DELAY=0.1
  local INDEX=0

  "${CMD[@]}" &
  PID=$!
  printf "%s …" "$MSG"
  while kill -0 $PID 2>/dev/null; do
    printf "\r%s …%s" "$MSG" "${SPINNER[$INDEX]}"
    INDEX=$(((INDEX + 1) % 4))
    sleep "$DELAY"
  done
  wait $PID
  local EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 0 ]; then
    printf "\r%s … ✅\n" "$MSG"
  else
    printf "\r%s … ❌  (exit %s)\n" "$MSG" "$EXIT_CODE"
  fi
}

# --- Phase 1: Host Operations ---
run_with_spinner "Removing chezmoi state" rm -f "$HOME/.local/share/chezmoi/state.db"
run_with_spinner "Deleting old toolbox" toolbox rm -f ${TOOLBOX_NAME} || true

echo "📦 Creating a fresh '${TOOLBOX_NAME}' toolbox for Fedora ${FEDORA_RELEASE}..."
toolbox create -r ${FEDORA_RELEASE} ${TOOLBOX_NAME}

# Override shell to bash before any entry attempt
sed -i 's|/usr/bin/zsh|/bin/bash|' /var/home/${USER}/.config/toolbox/${TOOLBOX_NAME}.json || true

run_with_spinner "Booting container" podman start ${TOOLBOX_NAME}

# --- Clean pause processes only; don't run podman inside container ---
podman exec --user james ${TOOLBOX_NAME} \
  pkill -x pause 2>/dev/null || true

# --- Phase 2: Container Setup ---
echo "🛠️  Configuring container as user 'james' via chezmoi..."
podman exec --user james -i ${TOOLBOX_NAME} /bin/bash <<EOF
set -e

# --- Prerequisites ---
echo "🏗️  Installing git & curl"
sudo dnf install -y git curl

# --- chezmoi Install ---
echo "👅  Installing chezmoi"
sudo sh -c "\$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
export PATH="\$PATH:/usr/local/bin"

# --- chezmoi Init ---
echo "🗄️  Cloning dot‑files & first apply"
chezmoi init --no-tty ${DOTFILES_REPO}
chezmoi apply --force --no-tty -v
EOF

# --- Phase 3: Finalization Pass ---
echo "🧰 Reapplying chezmoi to ensure all changes land cleanly..."
podman exec --user james -i ${TOOLBOX_NAME} chezmoi apply --force --no-tty -v

# --- Completion ---
echo "✅ All done! Your '${TOOLBOX_NAME}' (Fedora ${FEDORA_RELEASE}) toolbox has been rebuilt."
echo "Run 'toolbox enter ${TOOLBOX_NAME}' to get started."
