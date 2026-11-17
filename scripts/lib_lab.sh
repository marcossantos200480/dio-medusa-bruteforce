#!/usr/bin/env bash
# =============================================================================
# lib_lab.sh - Biblioteca comum de salvaguardas do laboratorio Medusa / DIO
# =============================================================================
# Uso:
#   SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=lib_lab.sh
#   source "$SCRIPT_DIR/lib_lab.sh"
#
# O que esta biblioteca oferece:
#   - Logs coloridos e padronizados
#   - Guarda de escopo: somente IPs de redes privadas aceitos
#   - Trava de seguranca: exige a flag --confirmo-lab para tocar a rede
#   - Diretorio de saida versionado por data/hora em logs/
#   - Utilidades de portas, comandos e modulos do Medusa
#
# IMPORTANTE: esta biblioteca NAO chama `set -e`, `set -u` ou `set -o pipefail`
# de proposito, para nao alterar o comportamento do script que a carrega.
# Cada script define o seu modo estrito conforme a necessidade.
# =============================================================================

# --- Constantes --------------------------------------------------------------
LAB_VERSAO="1.0.0"
LAB_AVISO_ESCOPO="Uso restrito a laboratorio isolado (host-only) com maquinas proprias."

# --- Cores (desligadas automaticamente quando nao ha terminal) --------------
if [[ -t 1 ]]; then
  LAB_COR_VERDE=$'\033[0;32m'
  LAB_COR_AMARELO=$'\033[0;33m'
  LAB_COR_VERMELHO=$'\033[0;31m'
  LAB_COR_AZUL=$'\033[0;36m'
  LAB_COR_NEGRITO=$'\033[1m'
  LAB_COR_RESET=$'\033[0m'
else
  LAB_COR_VERDE=""
  LAB_COR_AMARELO=""
  LAB_COR_VERMELHO=""
  LAB_COR_AZUL=""
  LAB_COR_NEGRITO=""
  LAB_COR_RESET=""
fi

# -----------------------------------------------------------------------------
# Logs
# -----------------------------------------------------------------------------
log_info()  { printf '%s[info]%s  %s\n' "$LAB_COR_AZUL" "$LAB_COR_RESET" "$*" >&2; }
log_ok()    { printf '%s[ ok ]%s  %s\n' "$LAB_COR_VERDE" "$LAB_COR_RESET" "$*" >&2; }
log_aviso() { printf '%s[aviso]%s %s\n' "$LAB_COR_AMARELO" "$LAB_COR_RESET" "$*" >&2; }
log_erro()  { printf '%s[erro]%s  %s\n' "$LAB_COR_VERMELHO" "$LAB_COR_RESET" "$*" >&2; }

die() {
  log_erro "$*"
  exit 1
}

# -----------------------------------------------------------------------------
# Caminhos
# -----------------------------------------------------------------------------
# Raiz do repositorio (um nivel acima de scripts/)
lab_raiz_repo() {
  local dir_script
  dir_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  ( cd -- "$dir_script/.." && pwd )
}

# Cria e ecoa um diretorio de saida em logs/<AAAAMMDD-HHMMSS>-<prefixo>
lab_dir_saida() {
  local prefixo="${1:-lab}"
  local raiz
  raiz="$(lab_raiz_repo)"
  local destino
  destino="$raiz/logs/$(date +%Y%m%d-%H%M%S)-$prefixo"
  mkdir -p -- "$destino" || die "Nao foi possivel criar o diretorio de saida: $destino"
  printf '%s\n' "$destino"
}

# -----------------------------------------------------------------------------
# Comandos
# -----------------------------------------------------------------------------
exigir_comando() {
  local cmd="$1"
  local dica="${2:-}"
  if ! command -v -- "$cmd" >/dev/null 2>&1; then
    log_erro "Comando obrigatorio nao encontrado: $cmd"
    [[ -n "$dica" ]] && log_info "Dica de instalacao: $dica"
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# Guarda de escopo - validacao de IPv4 e redes privadas
# -----------------------------------------------------------------------------
ipv4_valido() {
  local ip="${1:-}"
  local -a octetos
  [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  IFS=. read -r -a octetos <<< "$ip"
  local o
  for o in "${octetos[@]}"; do
    # 10# evita interpretacao octal (ex.: 010)
    (( 10#$o >= 0 && 10#$o <= 255 )) || return 1
  done
  return 0
}

# Aceita apenas faixas privadas / loopback:
#   10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8
ip_privado() {
  local ip="${1:-}"
  local a b _c _d
  ipv4_valido "$ip" || return 1
  IFS=. read -r a b _c _d <<< "$ip"
  (( 10#$a == 10 )) && return 0
  (( 10#$a == 172 && 10#$b >= 16 && 10#$b <= 31 )) && return 0
  (( 10#$a == 192 && 10#$b == 168 )) && return 0
  (( 10#$a == 127 )) && return 0
  return 1
}

# Resolve um hostname para lista de IPv4 (uma por linha)
lab_resolver_ipv4() {
  local alvo="$1"
  if command -v getent >/dev/null 2>&1; then
    getent ahostsv4 -- "$alvo" 2>/dev/null | awk '{print $1}' | sort -u
  else
    return 1
  fi
}

# Valida o alvo e ecoa o IPv4 a ser usado.
# Recusa: vazio, IP publico, hostname que resolva para IP publico, 0.0.0.0
lab_validar_alvo() {
  local alvo="${1:-}"
  local ip ip_final="" contador=0

  if [[ -z "$alvo" ]]; then
    log_erro "Alvo nao informado. Use --alvo <IP privado>."
    return 1
  fi

  if ipv4_valido "$alvo"; then
    if ! ip_privado "$alvo"; then
      log_erro "Escopo recusado: $alvo nao pertence a uma rede privada."
      log_info "Permitido: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 e 127.0.0.0/8."
      log_info "$LAB_AVISO_ESCOPO"
      return 1
    fi
    printf '%s\n' "$alvo"
    return 0
  fi

  # Hostname: resolve localmente e valida TODOS os enderecos encontrados
  while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    contador=$(( contador + 1 ))
    if ! ip_privado "$ip"; then
      log_erro "Escopo recusado: '$alvo' resolve para $ip, que e publico."
      log_info "$LAB_AVISO_ESCOPO"
      return 1
    fi
    [[ -z "$ip_final" ]] && ip_final="$ip"
  done < <(lab_resolver_ipv4 "$alvo")

  if (( contador == 0 )); then
    log_erro "Nao foi possivel resolver '$alvo' para um IPv4 local."
    return 1
  fi

  log_aviso "'$alvo' resolvido para $ip_final (hostname). Prefira o IP literal no laboratorio."
  printf '%s\n' "$ip_final"
}

# -----------------------------------------------------------------------------
# Trava de seguranca: --confirmo-lab
# -----------------------------------------------------------------------------
# Retorna 0 somente se a flag estiver presente nos argumentos.
lab_confirmado() {
  local arg
  for arg in "$@"; do
    [[ "$arg" == "--confirmo-lab" ]] && return 0
  done
  return 1
}

# Texto padrao do modo seguro
lab_mensagem_modo_seguro() {
  cat >&2 <<'TXT'

  ---------------------------------------------------------------
  MODO SEGURO (nenhum pacote enviado ao alvo)
  ---------------------------------------------------------------
  Este script nao executa nada contra a rede sem a flag
  --confirmo-lab. Ela existe para que voce confirme, de forma
  consciente, que:

    1. O alvo e uma VM SUA, em rede host-only isolada;
    2. Nao existe rota para redes de terceiros;
    3. Voce tem autorizacao para testar esse ambiente.

  Para executar de verdade, repita o comando acrescentando:
      --confirmo-lab
  ---------------------------------------------------------------

TXT
}

# -----------------------------------------------------------------------------
# Rede
# -----------------------------------------------------------------------------
# Testa se uma porta TCP aceita conexao. Retorna 0 se aberta.
# Uso: lab_porta_aberta <ip> <porta> [timeout_segundos]
lab_porta_aberta() {
  local host="$1"
  local porta="$2"
  local tempo="${3:-2}"
  timeout "$tempo" bash -c "exec 3<>/dev/tcp/${host}/${porta}" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Medusa
# -----------------------------------------------------------------------------
exigir_medusa() {
  if ! exigir_comando medusa "sudo apt update && sudo apt install -y medusa"; then
    return 1
  fi
  return 0
}

# Lista os modulos disponiveis (saida de `medusa -d`)
lab_modulos_medusa() {
  medusa -d 2>/dev/null \
    | grep -oE '[A-Za-z0-9_-]+\.mod' \
    | sed 's/\.mod$//' \
    | sort -u
}

lab_tem_modulo() {
  local modulo="$1"
  lab_modulos_medusa | grep -qx -- "$modulo"
}

# -----------------------------------------------------------------------------
# Cabecalho padrao dos relatorios
# -----------------------------------------------------------------------------
lab_cabecalho() {
  local titulo="$1"
  local destino="${2:-}"
  {
    printf '================================================================\n'
    printf ' %s\n' "$titulo"
    printf '================================================================\n'
    printf ' Data/hora : %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf ' Host      : %s\n' "$(hostname 2>/dev/null || echo desconhecido)"
    printf ' Usuario   : %s\n' "${USER:-desconhecido}"
    printf ' Versao lib: %s\n' "$LAB_VERSAO"
    printf ' Aviso     : %s\n' "$LAB_AVISO_ESCOPO"
    printf '================================================================\n'
  } >&2
  # Se um arquivo de destino foi pedido, grava tambem nele
  if [[ -n "$destino" ]]; then
    {
      printf '================================================================\n'
      printf ' %s\n' "$titulo"
      printf '================================================================\n'
      printf ' Data/hora : %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
      printf ' Host      : %s\n' "$(hostname 2>/dev/null || echo desconhecido)"
      printf ' Usuario   : %s\n' "${USER:-desconhecido}"
      printf ' Versao lib: %s\n' "$LAB_VERSAO"
      printf ' Aviso     : %s\n' "$LAB_AVISO_ESCOPO"
      printf '================================================================\n'
    } >> "$destino"
  fi
}
