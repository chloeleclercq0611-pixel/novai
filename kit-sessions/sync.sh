#!/bin/bash
# Synchronise ce dossier avec GitHub.
#   sync.sh pull  -> récupère la dernière version
#   sync.sh push  -> commite tous les changements et les envoie sur GitHub
# Utilisé par les hooks Claude Code ET par la surveillance automatique du Mac.
cd "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Verrou : évite que deux synchronisations se marchent dessus.
LOCK="$(git rev-parse --git-dir)/sync.lock"
for _ in $(seq 1 30); do mkdir "$LOCK" 2>/dev/null && break; sleep 1; done
mkdir "$LOCK" 2>/dev/null   # après 30 s on considère l'ancien verrou comme abandonné
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo main)
case "$1" in
  pull)
    git pull --rebase --autostash -q origin "$branch" 2>&1 >&2 || true ;;
  push)
    git add -A
    if ! git diff --cached --quiet; then
      files=$(git diff --cached --name-only | head -3 | tr '\n' ' ')
      git commit -q -m "Sync auto ($(hostname -s)) : $files"
    fi
    git pull --rebase --autostash -q origin "$branch" >/dev/null 2>&1 || true
    if [ -n "$(git log "origin/$branch..HEAD" 2>/dev/null | head -1)" ] || ! git rev-parse -q --verify "origin/$branch" >/dev/null; then
      git push -q -u origin "$branch" >&2 || echo "sync.sh : échec du push (réseau ?)" >&2
    fi ;;
esac
exit 0
