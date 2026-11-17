# 03 — Mitigações, hardening e detecção

> Para cada ataque executado no laboratório, aqui está a defesa correspondente —
> com configuração concreta e o que monitorar nos logs.

---

## 1. Panorama: por que o brute force funciona

Um ataque de credenciais só é viável quando **três condições** se somam:

```text
 1. A senha é previsível        (dicionário / senha padrão / senha curta)
 2. Não há limite de tentativas (nada impede 1 milhão de requisições)
 3. O atacante tem alcance      (o serviço está exposto e sem segmentação)
```

Eliminar **qualquer uma** das três quebra o ataque. As defesas abaixo atacam
principalmente a **#2**, que é a de menor custo e maior efeito imediato.

| Técnica | Condição explorada | Melhor defesa |
| --- | --- | --- |
| Força bruta pura | #2 (sem limite) | Rate limit + lockout |
| Ataque de dicionário | #1 (senha previsível) | Comprimento mínimo + bloqueio de senhas vazadas |
| **Password spraying** | #2 + política de lockout mal calibrada | Lockout progressivo + MFA + detecção por padrão |
| Credential stuffing | #1 (reuso de senha) | MFA + verificação contra bases vazadas |

---

## 2. Contramedidas universais

### 2.1 Rate limiting / throttling

Limite tentativas por **conta** e por **IP** em uma janela de tempo.

```text
Exemplo de política equilibrada:
  • 5 tentativas por conta em 1 minuto
  • 20 tentativas por IP em 1 minuto
  • atraso progressivo: 1s, 2s, 4s, 8s...
  • bloqueio de 15 min após 10 falhas
```

**Por que funciona:** o Medusa com `-t 2` faz ~2 tentativas/segundo. Com
`5/minuto`, o espaço de busca de 24 senhas × 20 usuários levaria horas em vez de
segundos — e geraria alerta muito antes.

### 2.2 Lockout progressivo (não permanente)

```text
5 falhas   → 1 minuto de bloqueio
10 falhas  → 5 minutos
15 falhas  → 15 minutos
20 falhas  → 1 hora + alerta ao SOC
```

> ⚠️ **Lockout permanente é uma armadilha.** Ele transforma o ataque em **DoS de
> contas**: o atacante bloqueia todos os usuários de propósito. Use bloqueio
> **temporário e progressivo**, e combine com MFA e detecção.

### 2.3 MFA — a defesa definitiva

MFA (TOTP, push, FIDO2/WebAuthn) resolve o problema na raiz: **mesmo com a senha
correta, o login falha**. É a única contramedida que sobrevive a uma senha
vazada, previsível ou descoberta por qualquer outro meio.

Prioridade de implantação:

```text
1. Contas administrativas e de serviço     ← sempre
2. Acesso remoto (VPN, SSH, RDP, SMB)
3. Aplicações web com dados sensíveis
4. Todo o resto
```

### 2.4 Política de senhas (NIST SP 800-63B)

O que **funciona** hoje:

```text
✅ Comprimento mínimo de 12–14 caracteres (comprimento > complexidade)
✅ Bloquear senhas conhecidamente vazadas e comuns
✅ Permitir frases-senha e gerenciadores de senha
✅ Comparar a senha contra uma lista de bloqueio (ex.: Have I Been Pwned, offline)
✅ Não exigir troca periódica sem motivo (isso gera padrões previsíveis: Senha1, Senha2...)
✅ Não impor regras de composição que empurrem o usuário para "P@ssw0rd1"
```

O que **não** funciona (e ainda é comum):

```text
❌ Troca obrigatória a cada 90 dias
❌ Exigir "1 maiúscula, 1 número, 1 símbolo" — o usuário faz "Senha@123"
❌ Comprimento mínimo de 8
❌ Lista de senhas proibidas desatualizada ("password", mas não "Password2024!")
```

### 2.5 Monitoramento e detecção

```text
Sinal                                   | Onde olhar
----------------------------------------|--------------------------------------
Rajada de falhas para UMA conta         | auth.log / Event 4625
Muitas falhas de UM IP                  | firewall / WAF / Apache access.log
Falhas para MUITAS contas, poucas senhas| ← assinatura clássica de SPRAYING
User-Agent do Medusa                    | Apache access.log
Login bem-sucedido após N falhas        | ← o sinal mais crítico
Login de IP/geolocalização incomum      | SIEM
```

**Regra de ouro:** um evento isolado não é ataque; **padrão + taxa** é ataque.
A detecção útil é sempre por correlação em janela de tempo.

---

## 3. Hardening — FTP (vsftpd)

### 3.1 Configuração segura

`/etc/vsftpd.conf`:

```ini
# Desabilitar login anônimo (o achado mais comum em laboratório)
anonymous_enable=NO

# Desabilitar login local se o FTP for usado apenas por usuários virtuais
local_enable=YES
write_enable=NO

# Chroot: prende o usuário no diretório home
chroot_local_user=YES
allow_writeable_chroot=NO

# Limitar tentativas de login por conexão
max_login_fails=3
delay_failed_login=2

# TLS obrigatório (FTPS) — a senha nunca trafega em claro
ssl_enable=YES
force_local_logins_ssl=YES
force_local_data_ssl=YES
rsa_cert_file=/etc/ssl/private/vsftpd.pem

# Restringir a uma faixa de IP (defesa em profundidade)
tcp_wrappers=YES
```

`/etc/hosts.allow`:

```text
vsftpd: 192.168.56.0/255.255.255.0
```

`/etc/hosts.deny`:

```text
vsftpd: ALL
```

### 3.2 A melhor defesa: não ter FTP

```text
O FTP transmite credenciais em texto claro. Se o requisito é transferência de
arquivos, use:
  • SFTP (SSH) — criptografado, autenticação forte, amplamente suportado
  • FTPS (FTP + TLS) — quando o FTP for obrigatório
  • S3/objeto com URLs assinadas — para integração entre sistemas
```

### 3.3 Fail2ban para FTP

`/etc/fail2ban/jail.d/vsftpd.local`:

```ini
[vsftpd]
enabled  = true
port     = ftp,ftp-data,ftps,ftps-data
filter   = vsftpd
logpath  = /var/log/vsftpd.log
maxretry = 3
findtime = 600
bantime  = 3600
```

### 3.4 Detecção

```bash
# Rajadas de falha
sudo grep "FAIL LOGIN" /var/log/vsftpd.log | awk '{print $9}' | sort | uniq -c | sort -rn

# Falhas por IP
sudo grep -c "FAIL LOGIN" /var/log/vsftpd.log
sudo journalctl -u vsftpd --since "10 min ago" | grep -i fail

# Login bem-sucedido logo após várias falhas (o alerta mais importante)
sudo grep "OK LOGIN" /var/log/vsftpd.log
```

---

## 4. Hardening — aplicações web (DVWA e equivalentes)

### 4.1 Anti-CSRF em todos os formulários

```php
<?php
// Gerar token na sessão
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
?>
<form method="post" action="login.php">
  <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
  <input type="text" name="username">
  <input type="password" name="password">
  <button type="submit">Login</button>
</form>

<?php
// Validar sempre
if (!hash_equals($_SESSION['csrf_token'] ?? '', $_POST['csrf_token'] ?? '')) {
    http_response_code(403);
    exit('Token inválido');
}
?>
```

> 🎯 **Efeito no ataque:** o Medusa `web-form` não mantém sessão nem captura o
> token a cada requisição → **todas as tentativas falham**. Este é um dos
> controles de melhor custo-benefício contra automação genérica.

### 4.2 Rate limiting por conta **e** por IP

```nginx
# nginx
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $request_uri zone=login_uri:10m rate=10r/m;

server {
    location = /login.php {
        limit_req zone=login burst=3 nodelay;
        limit_req_status 429;
        # ...
    }
}
```

```apache
# Apache + mod_ratelimit / mod_evasive
<Location "/login.php">
    SetEnvIf Request_URI "/login.php" login_request
    # mod_evasive: bloquear > 10 req/s do mesmo IP
    DOSPageCount 10
    DOSPageInterval 1
    DOSBlockingPeriod 300
</Location>
```

> ⚠️ **Rate limit só por IP é insuficiente** em ataques distribuídos. Por isso o
> limite precisa existir também **por conta** — e é aí que entra o lockout
> progressivo no servidor de autenticação.

### 4.3 CAPTCHA após N falhas

```text
Tentativas 1–3:  sem CAPTCHA (não atrapalha o usuário legítimo)
Tentativa 4+:    CAPTCHA obrigatório
Tentativa 10+:   bloqueio temporário + alerta
```

CAPTCHA (reCAPTCHA/Turnstile/hCaptcha) quebra automação "burra" e força o
atacante a resolver desafios — encarecendo o ataque em ordens de magnitude.

### 4.4 Mensagens de erro neutras

```php
// ❌ Revela se o usuário existe (enumeração de contas)
if (!$usuarioExiste)  echo "Usuário não encontrado";
if (!$senhaCorreta)   echo "Senha incorreta";

// ✅ Neutro
echo "Usuário ou senha inválidos";
```

Além disso: **tempo de resposta constante** (comparar a senha com `password_verify`
e executar o mesmo caminho quando o usuário não existe) para não vazar a
existência da conta pelo tempo de resposta.

### 4.5 MFA e WAF

```text
✅ MFA para todo usuário administrativo — sem exceção
✅ WAF com regras de brute force (ModSecurity CRS 930xxx, Cloudflare, AWS WAF)
✅ Bloqueio geográfico quando possível
✅ Alertas de "login bem-sucedido após N falhas" (o sinal mais crítico)
```

---

## 5. Hardening — SMB / Samba / Active Directory

### 5.0 O que este laboratório encontrou no alvo

Antes de qualquer recomendação genérica, vale registrar o que o `enum4linux -P`
revelou no Metasploitable 2 — porque é o retrato de uma configuração **sem
nenhuma defesa**:

```text
[+] Account Lockout Threshold: None      ← nenhum bloqueio de conta
[+] Locked Account Duration: 30 minutes
Password Complexity: Disabled            ← nenhuma exigência de complexidade
Minimum Password Length: 0               ← qualquer senha é aceita, inclusive vazia
```

| Achado | Efeito prático observado | Mitigação mínima |
| --- | --- | --- |
| `Lockout Threshold: None` | Tentativas ilimitadas — o ataque nunca trava a conta | Bloqueio progressivo após 5 falhas |
| `Minimum Password Length: 0` | `msfadmin:msfadmin` é aceita; senha vazia também | Mínimo de 14 caracteres |
| `Password Complexity: Disabled` | `password`, `123456` são válidas | Lista de bloqueio de senhas comuns |

> 🎯 **Conclusão que vale para qualquer serviço:** a dificuldade de um ataque
> mede a postura defensiva do alvo, não a habilidade de quem ataca. Neste
> laboratório, o cenário SMB foi o mais rápido de todos (2 segundos) — porque era
> o serviço mais mal configurado.

---

### 5.1 Desabilitar protocolos legados

```ini
# /etc/samba/smb.conf
[global]
   server min protocol = SMB2_10
   client min protocol = SMB2_10
   ntlm auth = ntlmv2-only
   restrict anonymous = 2
   map to guest = Never
   server signing = mandatory
```

> **SMBv1 nunca.** É o protocolo do WannaCry/EternalBlue, sem criptografia e
> com histórico de vulnerabilidades críticas.

### 5.2 Nunca expor SMB à internet

```text
Porta 445 exposta na internet = comprometimento em horas.
  • Bloquear 445/139 no firewall de borda (entrada E saída)
  • Segmentar SMB em VLAN dedicada
  • Acesso remoto: sempre via VPN, nunca SMB direto
  • Verificar regularmente: shodan "port:445 country:BR"
```

### 5.3 Política de senha e lockout no AD

```powershell
# Política de senha forte
Set-ADDefaultDomainPasswordPolicy -Identity exemplo.local `
  -MinPasswordLength 14 `
  -PasswordHistoryCount 24 `
  -ComplexityEnabled $true `
  -MaxPasswordAge 0                       # 0 = sem expiração forçada

# Lockout progressivo (com cuidado para não gerar DoS de contas)
Set-ADDefaultDomainPasswordPolicy -Identity exemplo.local `
  -LockoutThreshold 5 `
  -LockoutDuration 00:15:00 `
  -LockoutObservationWindow 00:15:00
```

Complementos essenciais:

```text
✅ Azure AD Password Protection (ou lista de senhas proibidas própria)
✅ LAPS para senhas de administrador local (únicas por máquina)
✅ gMSA para contas de serviço
✅ Tiered Administration: admins de domínio não fazem login em estações comuns
✅ Desabilitar NTLMv1 e remover LM hash
```

### 5.4 Monitoramento

```text
Event ID 4625  → falha de logon (o principal indicador)
Event ID 4624  → logon bem-sucedido (correlacionar com 4625 anteriores)
Event ID 4771  → falha de pré-autenticação Kerberos
Event ID 4740  → conta bloqueada ← lockout em ação
Event ID 4767  → conta desbloqueada
```

Consulta útil (PowerShell), para achar as contas mais atacadas:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=(Get-Date).AddHours(-1)} |
  ForEach-Object { $_.Properties[5].Value } |
  Group-Object | Sort-Object Count -Descending | Select-Object Count, Name -First 20
```

**A assinatura do spraying** nos logs: **muitos usuários diferentes, poucas
falhas por usuário, sempre do mesmo IP, em rajadas curtas** — o oposto do brute
force clássico (muitas falhas para um único usuário).

---

## 6. Tabela-resumo: ataque → defesa → verificação

| Ataque do laboratório | Defesa primária | Defesa secundária | Como verificar |
| --- | --- | --- | --- |
| `medusa -M ftp` | `max_login_fails=3` + Fail2ban | Desabilitar FTP / usar SFTP | `grep "FAIL LOGIN"` |
| `medusa -M web-form` | CSRF token + rate limit | CAPTCHA + MFA | Testar o mesmo `FORM-DATA` e receber 403/429 |
| `medusa -M smbnt` (spraying) | Lockout progressivo + MFA | Monitorar 4625 por padrão | `enum4linux -P` antes/depois |
| Qualquer um | **MFA** | Detecção + resposta | Rodar o laboratório de novo após aplicar |

### Teste de eficácia (recomendado)

Depois de aplicar as mitigações, **repita o laboratório** e registre:

```text
✅ O Medusa ainda encontra credenciais?     → esperado: NÃO
✅ O ataque é detectado?                    → esperado: SIM, em segundos
✅ As contas legítimas são bloqueadas?      → esperado: NÃO (só o atacante)
✅ O tempo do ataque aumentou?              → esperado: SIM, ordens de magnitude
```

Esse é o ciclo completo de um profissional de segurança: **atacar → medir →
defender → medir de novo**.

---

## 7. Referências normativas

| Documento | O que traz |
| --- | --- |
| **NIST SP 800-63B** | Diretrizes modernas de senha e autenticação |
| **OWASP ASVS v4** (V2) | Requisitos de autenticação verificáveis |
| **OWASP Blocking Brute Force Attacks** | Controles práticos |
| **MITRE ATT&CK T1110** | Tática de brute force e subtécnicas, com detecções |
| **CIS Controls v8** (4, 5, 6) | Configuração segura, gestão de contas e acesso |
| **LGPD** (Lei 13.709/2018) | Consequências legais de vazamento de dados pessoais |
| **Lei 12.737/2012** | Tipificação da invasão de dispositivo informático |
