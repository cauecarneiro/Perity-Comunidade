#!/bin/bash
# Cria Prumo/Configuracao.local com os SEUS identificadores (prefixo do app, equipe, iCloud).
# Use sem argumentos para responder às perguntas, ou passe tudo pelo ambiente:
#   PERITY_BUNDLE_PREFIX=com.joaosilva PERITY_TEAM_ID=ABCDE12345 PERITY_ICLOUD=false Scripts/configurar.sh
# Este script nunca pede nem grava segredo da Pluggy.
set -euo pipefail
cd "$(dirname "$0")/.."
arquivo="Configuracao.local"

if [ -f "$arquivo" ] && [ -z "${PERITY_BUNDLE_PREFIX:-}" ]; then
  read -r -p "$arquivo já existe. Substituir? [s/N] " r
  [[ "$r" =~ ^[sS]$ ]] || { echo "Mantido como estava."; exit 0; }
fi

prefixo="${PERITY_BUNDLE_PREFIX:-}"
if [ -z "$prefixo" ]; then
  echo "Prefixo do app: domínio ao contrário, só seu (ex.: com.joaosilva)."
  read -r -p "Prefixo: " prefixo
fi
prefixo="$(printf '%s' "$prefixo" | tr '[:upper:]' '[:lower:]')"
if ! [[ "$prefixo" =~ ^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+$ ]]; then
  echo "Prefixo inválido. Use letras minúsculas, números e hífen, com pontos (ex.: com.joaosilva)." >&2; exit 1
fi
case "$prefixo" in
  com.exemplo|com.seunome|com.example) echo "Troque o prefixo de exemplo pelo seu." >&2; exit 1;;
esac

equipe="${PERITY_TEAM_ID-__perguntar__}"
if [ "$equipe" = "__perguntar__" ]; then
  echo "ID da equipe de assinatura (10 caracteres). Deixe vazio para escolher no Xcode."
  read -r -p "Equipe: " equipe
fi
equipe="$(printf '%s' "$equipe" | tr '[:lower:]' '[:upper:]')"
if [ -n "$equipe" ] && ! [[ "$equipe" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "ID de equipe inválido: são 10 letras e números." >&2; exit 1
fi

icloud="${PERITY_ICLOUD:-}"
if [ -z "$icloud" ]; then
  read -r -p "Tem conta de desenvolvedor paga e quer sincronizar pelo iCloud? [s/N] " r
  [[ "$r" =~ ^[sS]$ ]] && icloud=true || icloud=false
fi
[ "$icloud" = "true" ] || icloud=false

umask 077
cat > "$arquivo" <<CONF
PERITY_BUNDLE_PREFIX=$prefixo
PERITY_TEAM_ID=$equipe
PERITY_ICLOUD=$icloud
CONF
echo "Pronto: Prumo/$arquivo (só para você; está no .gitignore)."
echo "Próximo passo: Scripts/gerar-projeto.sh"
