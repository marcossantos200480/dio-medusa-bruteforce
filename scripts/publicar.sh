#!/usr/bin/env bash
# =============================================================================
# publicar.sh - Publica este repositorio no GitHub (via gh CLI)
# =============================================================================
# Faz, em ordem, sempre com confirmacao antes de qualquer acao destrutiva:
#   1. Confere se o git e o gh estao instalados e autenticados
#   2. Confere a identidade da conta (login + nome/e-mail do git)
#   3. Revisa o que sera publicado (git status, arquivos ignorados)
#   4. Cria o repositorio PUBLICO no GitHub (se ainda nao existir)
#   5. Faz commit das alteracoes pendentes e push
#   6. Ajusta descricao e topicos do repositorio
#
# Uso:
#   bash scripts/publicar.sh --usuario SEU_USUARIO
#   bash scripts/publicar.sh --usuario SEU_USUARIO --nome outro-nome --privado
#   bash scripts/publicar.sh --usuario SEU_USUARIO --somente-checar
#
# Pre-requisito: gh auth login (nunca cole token no chat nem no codigo).
# =============================================================================

set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_lab.sh
source "$SCRIPT_DIR/lib_lab.sh"

RAIZ="$(lab_raiz_repo)"
USUARIO=""
NOME_REPO="dio-medusa-bruteforce"
PRIVADO=0
SOMENTE_CHECAR=0
DESCRICAO="Laboratorio isolado de brute force e password spraying com Medusa e Kali Linux - desafio DIO"
TOPICOS="cybersecurity,kali-linux,medusa,brute-force,password-spraying,metasploitable,dvwa,dio,pt-br"

uso() {
  cat <<'TXT'
Uso: publicar.sh --usuario <SEU_USUARIO_GITHUB> [opcoes]

Opcoes:
  -u, --usuario <login>   Login do GitHub onde o repo sera criado. Obrigatorio.
  -n, --nome <nome>       Nome do repositorio (padrao: dio-medusa-bruteforce)
      --privado           Cria como privado (padrao: publico)
      --somente-checar    Apenas valida ambiente e mostra o que seria feito
  -h, --help              Esta ajuda

Exemplo:
  gh auth login
  bash scripts/publicar.sh --usuario marcossantos200480
TXT
}

while (( $# > 0 )); do
  case "$1" in
    -u|--usuario)     USUARIO="${2:-}"; shift 2 ;;
    -n|--nome)        NOME_REPO="${2:-}"; shift 2 ;;
    --privado)        PRIVADO=1; shift ;;
    --somente-checar) SOMENTE_CHECAR=1; shift ;;
    -h|--help)        uso; exit 0 ;;
    *) die "Opcao desconhecida: $1 (use --help)" ;;
  esac
done

cd -- "$RAIZ" || die "Nao foi possivel entrar em $RAIZ"

# -----------------------------------------------------------------------------
# 1. Ferramentas e autenticacao
# -----------------------------------------------------------------------------
echo "================================================================="
echo " 1. AMBIENTE"
echo "================================================================="

exigir_comando git  "sudo apt install -y git"            || die "git ausente"
exigir_comando gh   "https://github.com/cli/cli#installation" || die "gh ausente"

if ! gh auth status >/dev/null 2>&1; then
  log_erro "gh nao esta autenticado."
  echo
  echo "Rode no terminal e siga as instrucoes (NAO cole token no chat):"
  echo "    gh auth login"
  echo
  echo "Escolha: GitHub.com > HTTPS > Login with a web browser"
  exit 1
fi

log_ok "git e gh disponiveis; gh autenticado."
gh auth status 2>&1 | sed 's/^/    /'

# -----------------------------------------------------------------------------
# 2. Identidade
# -----------------------------------------------------------------------------
echo
echo "================================================================="
echo " 2. IDENTIDADE"
echo "================================================================="

LOGIN_GH="$(gh api user --jq '.login' 2>/dev/null || true)"
[[ -n "$LOGIN_GH" ]] || die "Nao foi possivel ler o login da conta autenticada."

if [[ -z "$USUARIO" ]]; then
  log_aviso "Nenhum --usuario informado; usando a conta autenticada: $LOGIN_GH"
  USUARIO="$LOGIN_GH"
fi

if [[ "$USUARIO" != "$LOGIN_GH" ]]; then
  die "O --usuario ($USUARIO) difere da conta autenticada ($LOGIN_GH). Faca gh auth login com a conta correta."
fi

NOME_GIT="$(git config user.name  || true)"
EMAIL_GIT="$(git config user.email || true)"
if [[ -z "$NOME_GIT" || -z "$EMAIL_GIT" ]]; then
  log_aviso "git user.name/user.email nao configurados. Definindo valores locais..."
  git config user.name  "${NOME_GIT:-$USUARIO}"
  git config user.email "${EMAIL_GIT:-$USUARIO@users.noreply.github.com}"
fi
log_ok "Conta GitHub: $USUARIO"
log_ok "Autor do commit: $(git config user.name) <$(git config user.email)>"

# -----------------------------------------------------------------------------
# 3. Revisao do conteudo
# -----------------------------------------------------------------------------
echo
echo "================================================================="
echo " 3. CONTEUDO A PUBLICAR"
echo "================================================================="

mapfile -t ARQUIVOS < <(git ls-files --cached --others --exclude-standard)
echo "Arquivos que serao versionados (${#ARQUIVOS[@]}):"
printf '    %s\n' "${ARQUIVOS[@]}"

echo
echo "Arquivos ignorados pelo .gitignore (amostra):"
git status --ignored --short | grep '^!!' | head -n 20 | sed 's/^/    /' || echo "    (nenhum)"

# Barreira de seguranca: aborta se algo sensivel estiver prestes a subir
SUSPEITOS="$(printf '%s\n' "${ARQUIVOS[@]}" | grep -E '(^|/)(\.env|.*\.(pem|key|p12|pfx))$|/logs/.+\.(log|txt|csv)$' || true)"
if [[ -n "$SUSPEITOS" ]]; then
  log_erro "Arquivos potencialmente sensiveis na lista de publicacao:"
  printf '%s\n' "$SUSPEITOS" | sed 's/^/    /'
  die "Ajuste o .gitignore e o indice (git rm --cached ...) antes de publicar."
fi
log_ok "Nenhum segredo obvio na lista de publicacao."

if (( SOMENTE_CHECAR )); then
  echo
  log_info "--somente-checar: nenhuma alteracao feita no GitHub."
  exit 0
fi

# -----------------------------------------------------------------------------
# 4. Repositorio remoto
# -----------------------------------------------------------------------------
echo
echo "================================================================="
echo " 4. REPOSITORIO REMOTO"
echo "================================================================="

URL_REPO="https://github.com/$USUARIO/$NOME_REPO.git"

if gh repo view "$USUARIO/$NOME_REPO" >/dev/null 2>&1; then
  log_info "O repositorio $USUARIO/$NOME_REPO ja existe. Nao sera criado de novo."
else
  if (( PRIVADO )); then VIS="--private"; VIS_TXT="privado"; else VIS="--public"; VIS_TXT="publico"; fi
  log_info "Criando repositorio $VIS_TXT: $USUARIO/$NOME_REPO"
  gh repo create "$USUARIO/$NOME_REPO" $VIS \
    --description "$DESCRICAO" \
    --disable-wiki \
    || die "Falha ao criar o repositorio. Verifique se o nome ja esta em uso."
  log_ok "Repositorio criado: $URL_REPO"
fi

# Remote origin
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$URL_REPO"
else
  git remote add origin "$URL_REPO"
fi
log_ok "Remote origin -> $URL_REPO"

# -----------------------------------------------------------------------------
# 5. Commit e push
# -----------------------------------------------------------------------------
echo
echo "================================================================="
echo " 5. COMMIT E PUSH"
echo "================================================================="

git add -A

if git diff --cached --quiet; then
  log_info "Nada novo para commitar."
else
  git commit -m "docs: publica laboratorio de brute force com Medusa (desafio DIO)" \
    || die "Falha no commit."
  log_ok "Commit criado."
fi

BRANCH_ATUAL="$(git rev-parse --abbrev-ref HEAD)"
log_info "Enviando branch '$BRANCH_ATUAL' para origin..."
git push -u origin "$BRANCH_ATUAL" || die "Falha no push (verifique permissoes do token)."

# Garante que o branch main tambem exista/esteja atualizado
if [[ "$BRANCH_ATUAL" != "main" ]]; then
  git push origin "$BRANCH_ATUAL:main" || log_aviso "Nao foi possivel atualizar 'main' diretamente (protecao de branch?)."
fi

# -----------------------------------------------------------------------------
# 6. Metadados do repositorio
# -----------------------------------------------------------------------------
echo
echo "================================================================="
echo " 6. METADADOS"
echo "================================================================="

gh repo edit "$USUARIO/$NOME_REPO" \
  --description "$DESCRICAO" \
  --add-topic "$TOPICOS" \
  2>/dev/null && log_ok "Descricao e topicos atualizados." \
  || log_aviso "Nao foi possivel atualizar topicos (opcional, siga manualmente se quiser)."

# -----------------------------------------------------------------------------
# Resultado
# -----------------------------------------------------------------------------
echo
echo "================================================================="
echo " PUBLICADO"
echo "================================================================="
echo " Repositorio : https://github.com/$USUARIO/$NOME_REPO"
echo " Branch      : $BRANCH_ATUAL"
echo " Commits     : $(git rev-list --count HEAD)"
echo
echo " Proximos passos:"
echo "   1. Abra a URL acima e confira o README renderizado"
echo "   2. Preencha docs/RELATORIO_MODELO.md e images/ com os SEUS resultados"
echo "   3. Cole a URL no botao 'Entregar Projeto' da DIO"
echo "================================================================="
