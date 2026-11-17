#!/bin/bash
# Procura nos arquivos versionados (e nos preparados para commit) sinais de dado pessoal ou segredo.
# Imprime só "tipo | arquivo | quantidade", nunca o conteúdo achado. Saída diferente de zero se achar algo.
# Uso (na raiz do repositório): Prumo/Scripts/verificar-vazamentos.sh
# ATENÇÃO: é só uma REDE MÍNIMA (padrões simples). Passar aqui NÃO significa que está limpo. Antes de publicar,
# rode também gitleaks e trufflehog (inclusive no histórico) e revise o diff à mão.
# Se o gitleaks estiver instalado, este script o chama no final (só mostra arquivo e regra, nunca o conteúdo).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
FALSO_UUID='11111111-aaaa-4aaa-8aaa-111111111111'   # itemId fictício usado nos testes
achou=0
scan() { # nome, regex, [exceção por linha]
  local nome="$1" re="$2" exc="${3:-}" f c
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in Prumo/Scripts/verificar-vazamentos.sh) continue;; esac
    if [ -n "$exc" ]; then c=$(grep -aE "$re" "$f" 2>/dev/null | grep -avEc "$exc"); else c=$(grep -aEc "$re" "$f" 2>/dev/null); fi
    [ "${c:-0}" -gt 0 ] && { echo "$nome | $f | $c"; achou=1; }
  done < <({ git ls-files; git diff --cached --name-only --diff-filter=AM; } | sort -u)
}
scan "caminho-local"   '/Use[r]s/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+|C:\\Users\\'
scan "email"           '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 'noreply\.github\.com|@users\.noreply|@example\.|@exemplo\.|\.invalid'
scan "cpf"             '[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}' '123\.456\.789-09'
scan "uuid-itemId"     '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' "$FALSO_UUID"
scan "chave-privada"   'BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[bap]-|sk-[A-Za-z0-9]{20,}'
scan "segredo-literal" '(clientSecret|client_secret|CLIENT_SECRET|apiKey|X-API-KEY)["'"'"' ]*[:=]["'"'"' ]*["'"'"'][A-Za-z0-9._-]{12,}["'"'"']' 'segredo-teste|SEGREDO-SUPER-SECRETO|id-teste'
for f in $({ git ls-files; git diff --cached --name-only --diff-filter=AM; } | sort -u); do
  case "$f" in
    *.p8|*.p12|*.pem|*.key|*.cer|*.mobileprovision|*.env|.env*|*Configuracao.local|*.xcodeproj/*|*/App/iOS/Info.plist|*/App/macOS/Info.plist|*/Widgets/Info-*.plist|*.entitlements)
      echo "arquivo-que-nao-deve-ir | $f | -"; achou=1;;
  esac
done
# gitleaks opcional (--redact: nunca imprime o segredo achado).
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks detect --source . --no-banner --redact >/dev/null 2>&1; then
    echo "gitleaks | repositório e histórico | nada achado"
  else
    echo "gitleaks | achou algo ou falhou (rode: gitleaks detect --source . --no-banner --redact) | -"; achou=1
  fi
else
  echo "(gitleaks não instalado: rode também 'brew install gitleaks' e 'gitleaks detect'. trufflehog também é recomendado.)"
fi
if [ "$achou" = 0 ]; then echo "Nada suspeito encontrado pelos padrões simples (isso não prova que está limpo)."; else echo "Revise os arquivos acima ANTES de publicar."; fi
exit "$achou"
