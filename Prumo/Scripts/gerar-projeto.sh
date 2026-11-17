#!/bin/bash
# Gera Prumo.xcodeproj a partir de project.yml, usando a sua Configuracao.local.
# Rode depois de clonar e depois de cada pull/merge. O .xcodeproj nunca é versionado.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "xcodegen não encontrado. Instale com: brew install xcodegen"; exit 1; }
[ -f Configuracao.local ] || { echo "Falta a Configuracao.local. Rode antes: Scripts/configurar.sh"; exit 1; }

# Lê só as três chaves conhecidas (nada do arquivo é executado como comando).
ler() { grep -E "^$1=" Configuracao.local | head -1 | cut -d= -f2- | tr -d '\r' || true; }
PERITY_BUNDLE_PREFIX="$(ler PERITY_BUNDLE_PREFIX)"
PERITY_TEAM_ID="$(ler PERITY_TEAM_ID)"
PERITY_ICLOUD="$(ler PERITY_ICLOUD)"
[ "$PERITY_ICLOUD" = "true" ] || PERITY_ICLOUD=false

[[ "$PERITY_BUNDLE_PREFIX" =~ ^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+$ ]] || { echo "PERITY_BUNDLE_PREFIX inválido em Configuracao.local. Rode Scripts/configurar.sh"; exit 1; }
case "$PERITY_BUNDLE_PREFIX" in com.exemplo|com.seunome|com.example) echo "Troque o prefixo de exemplo pelo seu (Scripts/configurar.sh)."; exit 1;; esac
[ -z "$PERITY_TEAM_ID" ] || [[ "$PERITY_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "PERITY_TEAM_ID inválido em Configuracao.local."; exit 1; }

export PERITY_BUNDLE_PREFIX PERITY_TEAM_ID PERITY_ICLOUD
xcodegen generate --spec project.yml
echo "Pronto: Prumo.xcodeproj (esquemas: Prumo para iPhone, PrumoMac para Mac)"
[ "$PERITY_ICLOUD" = "true" ] && echo "iCloud: ligado (precisa de conta de desenvolvedor paga)." || echo "iCloud: desligado (dados só neste aparelho)."
