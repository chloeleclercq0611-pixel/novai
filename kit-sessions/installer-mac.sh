#!/bin/bash
# Installe le dossier partagé entre sessions Claude Code sur un Mac.
# Lancer dans le Terminal :
#   bash <(curl -fsSL https://raw.githubusercontent.com/chloeleclercq0611-pixel/novai/claude/awesome-rubin-k9tgho/kit-sessions/installer-mac.sh)
set -e
KIT="https://raw.githubusercontent.com/chloeleclercq0611-pixel/novai/claude/awesome-rubin-k9tgho/kit-sessions"
DOSSIER="$HOME/ClaudeCommun"
DEPOT="claude-commun"
VERSION_MIN="2.1.224"
etape() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }

version_ok() {  # $1 >= $2 ?
  local IFS=.; local a=($1) b=($2)
  for i in 0 1 2; do
    [ "${a[i]:-0}" -gt "${b[i]:-0}" ] && return 0
    [ "${a[i]:-0}" -lt "${b[i]:-0}" ] && return 1
  done; return 0
}

etape "1/6 Vérification de Claude Code (minimum $VERSION_MIN)"
if ! command -v claude >/dev/null; then echo "Claude Code n'est pas installé. Installe-le d'abord : https://claude.com/claude-code"; exit 1; fi
V=$(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "Version actuelle : $V"
if version_ok "$V" "$VERSION_MIN"; then echo "OK, la messagerie entre sessions est disponible."
else
  echo "Trop ancienne : mise à jour…"; claude update || true
  V=$(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  version_ok "$V" "$VERSION_MIN" && echo "Mis à jour : $V" || { echo "La mise à jour a échoué (version $V). Lance 'claude update' puis relance ce script."; exit 1; }
fi

etape "2/6 Outils nécessaires (Homebrew, GitHub CLI, fswatch)"
if ! command -v brew >/dev/null; then
  echo "Installation de Homebrew (ton mot de passe de Mac va être demandé, c'est normal)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi
command -v gh >/dev/null || brew install gh
command -v fswatch >/dev/null || brew install fswatch

etape "3/6 Connexion à GitHub"
if ! gh auth status >/dev/null 2>&1; then
  echo "Choisis : GitHub.com > HTTPS > Yes > Login with a web browser."
  echo "Un code va s'afficher : copie-le, appuie sur Entrée, colle-le dans la page qui s'ouvre."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git
LOGIN=$(gh api user --jq .login)
echo "Connectée en tant que : $LOGIN"
git config --global user.name >/dev/null || git config --global user.name "$LOGIN"
git config --global user.email >/dev/null || git config --global user.email "$(gh api user --jq .id)+$LOGIN@users.noreply.github.com"

etape "4/6 Création du dossier $DOSSIER"
mkdir -p "$DOSSIER/.claude" && cd "$DOSSIER"
[ -d .git ] || git init -q -b main
for f in CLAUDE.md:CLAUDE.md settings.json:.claude/settings.json sync.sh:.claude/sync.sh surveiller.sh:.claude/surveiller.sh gitignore:.gitignore; do
  src=${f%%:*}; dst=${f#*:}
  [ -e "$dst" ] && [ "$dst" = CLAUDE.md ] && { echo "CLAUDE.md existe déjà, je le garde."; continue; }
  curl -fsSL "$KIT/$src" -o "$dst"
done
chmod +x .claude/sync.sh .claude/surveiller.sh
[ -e NOTES-PARTAGEES.md ] || printf '# Notes partagées entre sessions\n\nInformations utiles à toutes les sessions (ajoutées par les sessions elles-mêmes).\n' > NOTES-PARTAGEES.md
git add -A && (git diff --cached --quiet || git commit -q -m "Mise en place du dossier partagé entre sessions Claude Code")

etape "5/6 Création du dépôt GitHub privé $LOGIN/$DEPOT"
if git remote get-url origin >/dev/null 2>&1; then echo "Dépôt déjà relié."
elif gh repo view "$LOGIN/$DEPOT" >/dev/null 2>&1; then git remote add origin "https://github.com/$LOGIN/$DEPOT.git"; git pull -q --rebase origin main || true
else gh repo create "$DEPOT" --private --source . --remote origin
fi
git push -q -u origin main

etape "6/6 Surveillance automatique des fichiers que tu déposes"
PLIST="$HOME/Library/LaunchAgents/com.claude-commun.surveiller.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.claude-commun.surveiller</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$DOSSIER/.claude/surveiller.sh</string></array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$DOSSIER/.git/surveiller.log</string>
</dict></plist>
PL
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

printf '\n\033[1;32mTerminé !\033[0m\n'
echo "Dossier partagé : $DOSSIER"
echo "Dépôt privé     : https://github.com/$LOGIN/$DEPOT"
echo "Pour travailler : ouvre un Terminal, tape   cd ~/ClaudeCommun && claude"
open "$DOSSIER"
