# 05 — Publicar no GitHub e entregar na DIO

> Guia completo, do zero, para colocar este projeto no seu GitHub e colar o link
> no botão **"Entregar Projeto"** da DIO.
>
> ⚠️ **Nunca** cole tokens, senhas ou chaves neste repositório ou no chat.
> A autenticação é feita **por você**, no seu terminal, com `gh auth login`.

---

## 1. Antes de tudo: o que **não** pode ser publicado

O `.gitignore` já bloqueia a maior parte, mas confira:

```text
❌ .env, arquivos *.key, *.pem, *.p12
❌ logs/ completos (contêm credenciais em texto claro)
❌ Credenciais reais descobertas no laboratório (use placeholders no relatório)
❌ IPs, hostnames ou dados de empresas/clientes
❌ Capturas de tela de sistemas que não são seus
✅ Use sempre: 192.168.56.102, "admin", "password" — dados fictícios de lab
```

Verifique o que está prestes a ser publicado:

```bash
git status
git ls-files                        # tudo que está versionado
git status --ignored --short        # o que está sendo ignorado
```

> 💡 O script `scripts/publicar.sh` faz essa checagem automaticamente e **aborta**
> se encontrar algo suspeito na lista de publicação.

---

## 2. Forma recomendada — `gh` CLI (mais rápido)

### 2.1 Instalar o GitHub CLI

| Sistema | Comando |
| --- | --- |
| Kali/Debian/Ubuntu | `sudo apt update && sudo apt install -y gh` |
| Fedora | `sudo dnf install -y gh` |
| Arch | `sudo pacman -S github-cli` |
| macOS | `brew install gh` |
| Windows | `winget install --id GitHub.cli` |

### 2.2 Autenticar (você, no seu terminal)

```bash
gh auth login
```

Responda:

```text
? What account do you want to log into?      → GitHub.com
? What is your preferred protocol for Git?   → HTTPS
? How would you like to authenticate?        → Login with a web browser
! One-time code: ABCD-1234
   (abra https://github.com/login/device e cole o código)
```

Confirme:

```bash
gh auth status
# ✓ Logged in to github.com as SEU_USUARIO (oauth_token)
```

### 2.3 Publicar com o script do repositório

```bash
cd dio-medusa-bruteforce

# 1) Só checar o ambiente (não altera nada no GitHub)
bash scripts/publicar.sh --usuario SEU_USUARIO --somente-checar

# 2) Publicar de verdade
bash scripts/publicar.sh --usuario SEU_USUARIO
```

O script:

```text
✅ Confere git + gh + autenticação
✅ Valida que o --usuario é a conta autenticada
✅ Lista os arquivos que serão publicados e bloqueia segredos óbvios
✅ Cria o repositório público (se não existir)
✅ Faz commit e push
✅ Define descrição e tópicos do repositório
✅ Imprime a URL final
```

Opções:

```bash
bash scripts/publicar.sh --usuario SEU_USUARIO --nome outro-nome   # outro nome de repo
bash scripts/publicar.sh --usuario SEU_USUARIO --privado           # repo privado
```

> ⚠️ **Repositório privado não serve para a entrega da DIO** — o avaliador precisa
> conseguir abrir o link. Use público.

### 2.4 Publicação manual (se preferir não usar o script)

```bash
cd dio-medusa-bruteforce

# Criar o repositório público (sem adicionar README, para não conflitar)
gh repo create dio-medusa-bruteforce --public \
  --description "Laboratorio isolado de brute force com Medusa e Kali Linux - desafio DIO" \
  --source=. --remote=origin --push

# Ou, se o repositório já existir:
git remote add origin https://github.com/SEU_USUARIO/dio-medusa-bruteforce.git
git branch -M main
git push -u origin main

# Metadados (opcional, mas agrega)
gh repo edit --description "Laboratorio isolado de brute force com Medusa e Kali Linux - desafio DIO" \
             --add-topic cybersecurity,kali-linux,medusa,brute-force,password-spraying,dio
```

---

## 3. Forma alternativa — interface web

1. Acesse <https://github.com/new>
2. **Repository name**: `dio-medusa-bruteforce`
3. **Description**: `Laboratorio isolado de brute force com Medusa e Kali Linux - desafio DIO`
4. Marque **Public**
5. **Não** marque "Add a README file" (você já tem um)
6. **Create repository**

Depois, envie os arquivos:

```bash
cd dio-medusa-bruteforce

# Primeira configuração (uma vez por máquina)
git config --global user.name  "Seu Nome"
git config --global user.email "seu-email@exemplo.com"

git init -b main
git add .
git commit -m "docs: adiciona laboratorio de brute force com Medusa (desafio DIO)"
git remote add origin https://github.com/SEU_USUARIO/dio-medusa-bruteforce.git
git push -u origin main
```

> 🔐 No push, o GitHub **não aceita mais senha de conta**. Use:
> - um **Personal Access Token** como senha (`gh auth login` evita isso), ou
> - **SSH**: `git remote set-url origin git@github.com:SEU_USUARIO/dio-medusa-bruteforce.git`
>   (requer chave SSH configurada).

---

## 4. Verificação pós-publicação

```bash
# O repositório existe e é público?
gh repo view SEU_USUARIO/dio-medusa-bruteforce --json name,isPrivate,url

# Quantos arquivos subiram?
gh api repos/SEU_USUARIO/dio-medusa-bruteforce/git/trees/main?recursive=1 --jq '.tree | length'

# Confira no navegador (melhor teste: janela anônima)
#   → o README renderiza com formatação?
#   → as imagens aparecem?
#   → os links internos abrem?
```

### Checklist de qualidade da entrega

```text
[ ] O repositório é PÚBLICO (testei em janela anônima)
[ ] O README renderiza corretamente (tabelas, badges, índice)
[ ] Todos os links internos abrem (docs/*, wordlists/*, scripts/*)
[ ] Nenhum log com credenciais foi publicado
[ ] O arquivo LICENSE está presente e com o seu nome correto
[ ] O .gitignore está presente
[ ] A descrição do repositório está preenchida
[ ] Os tópicos (topics) estão definidos
[ ] O relatório (docs/RELATORIO_MODELO.md) foi preenchido com os SEUS resultados
[ ] As capturas de tela estão em images/ e referenciadas no README
```

---

## 5. Entregar na DIO

1. Acesse a página do desafio no bootcamp:
   **"Criando um Ataque Brute Force de senhas com Medusa e Kali Linux"**
2. Role até a seção **"Entregar Projeto"**
3. Cole a URL:

```text
https://github.com/SEU_USUARIO/dio-medusa-bruteforce
```

4. Preencha a descrição — sugestão pronta abaixo 👇
5. Envie e confira se aparece o status **"Entregue"**

> 📅 Se a entrega estiver dentro do prazo do bootcamp, o projeto entra na
> avaliação e conta para o certificado. Entregas após o prazo podem não ser
> consideradas.

### 5.1 Descrição sugerida para a DIO

```text
Projeto prático do desafio "Criando um Ataque Brute Force de senhas com Medusa e
Kali Linux".

Montei um laboratório isolado no VirtualBox com duas máquinas: Kali Linux
(atacante) e Metasploitable 2 (alvo), conectadas apenas por rede host-only, sem
qualquer acesso à internet. Executei três cenários reais de auditoria de
credenciais com o Medusa:

1) FTP (medusa -M ftp): força bruta com dicionário contra o vsftpd, incluindo o
   ajuste -c 1000 necessário para lidar com o mecanismo anti-bruteforce do
   serviço.
2) Formulário web do DVWA (medusa -M web-form): uso de FORM-DATA e DENY-SIGNAL
   para reproduzir o POST do login, e análise de como o token anti-CSRF quebra a
   automação (desenvolvi um verificador em Python que trata o token).
3) SMB (medusa -M smbnt): enumeração com enum4linux e password spraying,
   aplicando a lógica de uma senha contra muitos usuários para reduzir o risco de
   lockout.

Para cada cenário documentei o passo a passo, as flags do Medusa, os erros que
encontrei e as mitigações correspondentes (rate limiting, lockout progressivo,
MFA, CSRF token, política de senhas do NIST, Fail2ban e detecção por logs).

O repositório inclui ainda scripts com salvaguardas de escopo (só aceitam IPs de
rede privada e exigem confirmação explícita), wordlists didáticas e um modelo de
relatório para as evidências.

Todo o trabalho foi executado exclusivamente em ambiente próprio e isolado, com
fins educacionais.
```

---

## 6. Atualizações futuras

Depois de publicar, quando quiser atualizar:

```bash
# fluxo normal
git add .
git commit -m "docs: adiciona resultados do cenario 2 (DVWA)"
git push
```

Ou, com o script:

```bash
bash scripts/publicar.sh --usuario SEU_USUARIO
```

> 💡 Commits pequenos e com mensagem clara (`docs:`, `feat:`, `fix:`) mostram
> cuidado com o projeto — e são um diferencial na avaliação de portfólio.

---

## 7. Problemas comuns

| Erro | Causa | Solução |
| --- | --- | --- |
| `gh: command not found` | CLI ausente | `sudo apt install -y gh` |
| `gh: Not logged into any GitHub hosts` | Sem autenticação | `gh auth login` |
| `remote: Permission to ... denied` | Token sem permissão ou conta errada | `gh auth login` de novo; confira `gh auth status` |
| `failed to push some refs` | Histórico divergente | `git pull --rebase origin main` |
| `Updates were rejected` | Remote tem commits que você não tem | `git pull` e resolva conflitos |
| `fatal: remote origin already exists` | Remote já configurado | `git remote set-url origin <nova-url>` |
| `Support for password authentication was removed` | Senha em vez de token | `gh auth login` ou use SSH |
| README aparece como texto puro | Arquivo sem o nome correto | Deve ser `README.md`, na raiz |
| Imagens não aparecem | Caminho errado | Use caminhos relativos: `images/arquivo.png` |
