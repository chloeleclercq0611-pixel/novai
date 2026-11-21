#!/bin/bash
# Surveille le dossier partagé (tourne en arrière-plan sur le Mac, lancé par launchd).
# - Dès qu'un fichier est ajouté/modifié/supprimé : commit + push (après 5 s de calme).
# - Toutes les 2 minutes sans changement : récupère les nouveautés des autres sessions.
DOSSIER="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$DOSSIER/.claude/sync.sh"
export CLAUDE_PROJECT_DIR="$DOSSIER"
"$SYNC" push
while true; do
  while true; do
    if read -r -t 120 _; then "$SYNC" push
    elif [ $? -gt 128 ]; then "$SYNC" pull   # délai écoulé
    else break                                # fswatch s'est arrêté
    fi
  done < <(fswatch -o -l 5 --exclude '/\.git/' --exclude '\.DS_Store' "$DOSSIER")
  sleep 5
done
