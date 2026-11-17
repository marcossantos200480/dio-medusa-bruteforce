#!/usr/bin/env bash
# =============================================================================
# preflight_lab.sh - Checagem do laboratorio ANTES de qualquer teste
# =============================================================================
# Verifica, sem enviar nenhum pacote ao alvo:
#   1. Ferramentas instaladas (nmap, medusa, curl, python3 ...)
#   2. Modulos do Medusa disponiveis na maquina
#   3. Isolamento de rede: alvo em faixa privada e sem rota para a internet
#   4. Arquivos de wordlist do repositorio
#   5. Servicos do alvo respondendo (portas esperadas por cenario)
#
# Uso:
#   ./scripts/preflight_lab.sh --alvo 192.168.56.101
#   ./scripts/preflight_lab.sh --alvo 192.168.56.101 --cenario web --verbose
#   ./scripts/preflight_lab.sh --alvo 192.168.56.101 --confirmo-lab   # testa portas
#
# Sem --confirmo-lab o script roda apenas as checagens locais (offline).
# =============================================================================

# Nao usamos `set -e`: queremos acumular falhas e seguir checando.
set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_lab.sh
source "$SCRIPT_DIR/lib_lab.sh"

ALVO=""
CENARIO="todos"
VERBOSE=0
RELATORIO=""
FALHAS=0
AVISOS=0
CONFIRMADO=0

uso() {
  cat <<'TXT'
Uso: preflight_lab.sh --alvo <IP_PRIVADO> [opcoes]

Opcoes:
  -a, --alvo <IP>      IP (ou hostname privado) da VM alvo. Obrigatorio.
  -c, --cenario <c>    ftp | web | smb | todos (padrao: todos)
  -r, --relatorio <f>  Salva a saida em arquivo de texto
  -v, --verbose        Mostra detalhes extras
      --confirmo-lab   Permite testar portas do alvo (envia conexoes TCP)
  -h, --help           Esta ajuda

Exemplos:
  ./scripts/preflight_lab.sh --alvo 192.168.56.101
  ./scripts/preflight_lab.sh --alvo 192.168.56.101 --cenario ftp --confirmo-lab -v
TXT
}

# --- Argumentos --------------------------------------------------------------
while (( $# > 0 )); do
  case "$1" in
    -a|--alvo)       ALVO="${2:-}"; shift 2 ;;
    -c|--cenario)    CENARIO="${2:-}"; shift 2 ;;
    -r|--relatorio)  RELATORIO="${2:-}"; shift 2 ;;
    -v|--verbose)    VERBOSE=1; shift ;;
    --confirmo-lab)  CONFIRMADO=1; shift ;;
    -h|--help)       uso; exit 0 ;;
    *) die "Opcao desconhecida: $1 (use --help)" ;;
  esac
done

case "$CENARIO" in
  ftp|web|smb|todos) ;;
  *) die "Cenario invalido: '$CENARIO' (use ftp, web, smb ou todos)" ;;
esac

[[ -n "$ALVO" ]] || { uso; die "Informe --alvo <IP da VM alvo>."; }

# Saida duplicada para tela + arquivo (quando -r for informado)
if [[ -n "$RELATORIO" ]]; then
  mkdir -p -- "$(dirname -- "$RELATORIO")"
  exec > >(tee -a -- "$RELATORIO") 2>&1
fi

registrar_falha() { FALHAS=$(( FALHAS + 1 )); log_erro "$*"; }
registrar_aviso() { AVISOS=$(( AVISOS + 1 )); log_aviso "$*"; }

linha() { printf '%s\n' "----------------------------------------------------------------"; }

# -----------------------------------------------------------------------------
# 0. Cabecalho + guarda de escopo
# -----------------------------------------------------------------------------
lab_cabecalho "PREFLIGHT DO LABORATORIO - Medusa / DIO"

ALVO_IP="$(lab_validar_alvo "$ALVO")" || die "Alvo recusado pela guarda de escopo."
log_ok "Alvo validado: $ALVO_IP (rede privada)"

# -----------------------------------------------------------------------------
# 1. Ferramentas
# -----------------------------------------------------------------------------
linha
echo "1) FERRAMENTAS LOCAIS"
linha

checar_ferramenta() {
  local cmd="$1" obrig="$2" dica="$3" opcional="${4:-}"
  if command -v -- "$cmd" >/dev/null 2>&1; then
    local versao
    versao="$("$cmd" --version 2>&1 | head -n1 | cut -c1-70)"
    log_ok "$(printf '%-12s %s' "$cmd" "${versao:-instalado}")"
  elif [[ "$obrig" == "obrigatorio" ]]; then
    registrar_falha "$(printf '%-12s AUSENTE  -> %s' "$cmd" "$dica")"
  else
    registrar_aviso "$(printf '%-12s ausente (opcional%s) -> %s' "$cmd" "${opcional:+: $opcional}" "$dica")"
  fi
}

checar_ferramenta nmap    obrigatorio "sudo apt install -y nmap"
checar_ferramenta medusa  obrigatorio "sudo apt install -y medusa"
checar_ferramenta curl    obrigatorio "sudo apt install -y curl"
checar_ferramenta python3 obrigatorio "sudo apt install -y python3"
checar_ferramenta timeout obrigatorio "pacote coreutils"
checar_ferramenta smbclient opcional "sudo apt install -y smbclient" "cenario SMB"
checar_ferramenta enum4linux opcional "sudo apt install -y enum4linux" "cenario SMB"

# -----------------------------------------------------------------------------
# 2. Modulos do Medusa
# -----------------------------------------------------------------------------
linha
echo "2) MODULOS DO MEDUSA"
linha

if command -v medusa >/dev/null 2>&1; then
  for mod in ftp web-form smbnt; do
    if lab_tem_modulo "$mod"; then
      log_ok "modulo presente: $mod"
    else
      registrar_falha "modulo ausente: $mod (reinstale o pacote medusa)"
    fi
  done
  if (( VERBOSE )); then
    echo "--- medusa -d ---"
    medusa -d 2>/dev/null | sed 's/^/    /'
  fi
else
  registrar_falha "medusa nao instalado: nao foi possivel listar modulos"
fi

# -----------------------------------------------------------------------------
# 3. Isolamento de rede
# -----------------------------------------------------------------------------
linha
echo "3) ISOLAMENTO DE REDE"
linha

if [[ -n "$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'via [0-9.]+' | head -n1)" ]]; then
  registrar_aviso "Existe rota padrao para a internet. Confirme que a VM atacante usa"
  registrar_aviso "APENAS o adaptador host-only (vboxnet0) durante os testes."
else
  log_ok "Nenhuma rota padrao para a internet (bom sinal de isolamento)"
fi

if lab_porta_aberta "$ALVO_IP" 22 2; then
  registrar_aviso "Porta 22 (SSH) responde no alvo. Fora do escopo do desafio: nao teste."
fi

if (( VERBOSE )); then
  echo "--- rotas ---"
  ip -4 route | sed 's/^/    /'
  echo "--- interfaces ---"
  ip -4 -brief addr | sed 's/^/    /'
fi

# -----------------------------------------------------------------------------
# 4. Wordlists do repositorio
# -----------------------------------------------------------------------------
linha
echo "4) WORDLISTS DO REPOSITORIO"
linha

RAIZ="$(lab_raiz_repo)"
for arquivo in usuarios.txt senhas.txt usuarios-smb.txt senhas-spray.txt; do
  caminho="$RAIZ/wordlists/$arquivo"
  if [[ -f "$caminho" ]]; then
    total="$(grep -vcE '^\s*(#|$)' -- "$caminho" || true)"
    log_ok "$(printf '%-20s %s entradas uteis' "$arquivo" "$total")"
    if (( VERBOSE )); then
      sed 's/^/    | /' -- "$caminho"
    fi
  else
    registrar_falha "wordlist ausente: wordlists/$arquivo"
  fi
done

# -----------------------------------------------------------------------------
# 5. Portas do alvo (exige --confirmo-lab)
# -----------------------------------------------------------------------------
linha
echo "5) SERVICOS DO ALVO (portas)"
linha

portas_do_cenario() {
  case "$CENARIO" in
    ftp) echo "21" ;;
    web) echo "80" ;;
    smb) echo "139 445" ;;
    todos) echo "21 80 139 445" ;;
  esac
}

if (( CONFIRMADO )); then
  for porta in $(portas_do_cenario); do
    if lab_porta_aberta "$ALVO_IP" "$porta" 3; then
      log_ok "porta $porta/tcp ABERTA em $ALVO_IP"
    else
      registrar_aviso "porta $porta/tcp fechada ou filtrada em $ALVO_IP"
    fi
  done

  if (( VERBOSE )) && command -v nmap >/dev/null 2>&1; then
    echo "--- nmap -sV (portas do cenario) ---"
    # shellcheck disable=SC2046
    nmap -Pn -sV -p "$(portas_do_cenario | tr ' ' ',')" "$ALVO_IP" 2>/dev/null | sed 's/^/    /'
  fi
else
  log_aviso "Teste de portas ignorado (modo seguro, sem --confirmo-lab)."
  lab_mensagem_modo_seguro
fi

# -----------------------------------------------------------------------------
# Resultado
# -----------------------------------------------------------------------------
linha
echo "RESULTADO"
linha
if (( FALHAS == 0 )); then
  log_ok "Preflight concluido: $FALHAS falha(s), $AVISOS aviso(s). Pode seguir para o cenario."
else
  log_erro "Preflight concluido com $FALHAS falha(s) e $AVISOS aviso(s). Resolva antes de atacar."
fi
[[ -n "$RELATORIO" ]] && log_info "Relatorio salvo em: $RELATORIO"

(( FALHAS == 0 )) || exit 1
exit 0
