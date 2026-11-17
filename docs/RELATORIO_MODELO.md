# Relatório do Laboratório — Brute Force com Medusa

> ⚠️ **MODELO EM BRANCO.** Este arquivo é um template: substitua os campos
> entre `<...>` pelos **seus** resultados reais, após executar os três cenários.
>
> **Este repositório não contém resultados fabricados.** Se um campo não foi
> medido, escreva "não executado" — um dado honesto vale mais que um número
> inventado.

---

## 1. Identificação

| Campo | Valor |
| --- | --- |
| Nome | `<SEU_NOME_OU_USUARIO>` |
| GitHub | `@<SEU_USUARIO>` |
| Bootcamp | Cibersegurança do Zero à Prática — DIO |
| Desafio | Criando um Ataque Brute Force de senhas com Medusa e Kali Linux |
| Data dos testes | `<AAAA-MM-DD>` |
| Versão do Kali | `<kali 2024.x>` |
| Versão do Medusa | `<saída de: medusa -V>` |
| Versão do Metasploitable | `2` |
| Versão do DVWA | `<v1.x>` |

---

## 2. Ambiente

| Item | Atacante | Alvo |
| --- | --- | --- |
| VM | Kali Linux | Metasploitable 2 |
| IP | `192.168.56.102` | `192.168.56.101` |
| Rede | Host-only `vboxnet0` | Host-only `vboxnet0` |
| RAM / vCPU | `<3 GB / 2>` | `<1 GB / 1>` |
| Gateway | nenhum | nenhum |
| Acesso à internet | **nenhum** (verificado) | **nenhum** |

### 2.1 Evidência do isolamento

```bash
$ ip route
<cole a saída real>

$ ping -c 2 8.8.8.8
<cole a saída real — deve falhar>
```

---

## 3. Reconhecimento

```bash
$ nmap -Pn -sV -p 21,80,139,445 192.168.56.101
<cole a saída real>
```

| Porta | Serviço | Versão detectada | Relevância |
| --- | --- | --- | --- |
| 21 | `<ftp>` | `<vsftpd 2.3.4>` | Cenário 1 |
| 80 | `<http>` | `<Apache 2.2.8>` | Cenário 2 (DVWA) |
| 139/445 | `<smb>` | `<Samba 3.x>` | Cenário 3 |

```bash
$ enum4linux -a 192.168.56.101
<cole a seção de usuários e a Password Policy>

$ nmap -Pn -p 21 --script ftp-anon 192.168.56.101
<login anônimo permitido? cole a saída>
```

**Usuários válidos descobertos:** `<quantidade>` → `<lista>`

**Política de senha do SMB:** `Minimum password length = <x>`, `Lockout Threshold = <y>`
> 💡 Se `Lockout Threshold` for diferente de `0`, o spraying precisa de pausas
> maiores. Registre isso: é o dado que decide a estratégia.

---

## 4. Cenário 1 — FTP

### 4.1 Comando executado

```bash
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

### 4.2 Saída (trecho real)

```text
<cole a saída do Medusa aqui>
```

### 4.3 Resultado

| Campo | Valor |
| --- | --- |
| Usuários testados | `<20>` |
| Senhas testadas | `<24>` |
| Total de tentativas | `<480>` |
| **Credencial válida** | `<usuario>` / `<senha>` |
| Tempo total | `<X min Y s>` |
| Flags que fizeram diferença | `<ex.: -c 1000 sem o qual nada funcionou>` |

### 4.4 Validação do acesso

```bash
$ ftp 192.168.56.101
<cole a sessão real: 230 Login successful, ls>
```

### 4.5 Dificuldades encontradas

`<ex.: sem -c 1000 o Medusa reportava "connection refused" em todas as tentativas;
com -t 8 o vsftpd derrubava a conexão e o resultado virava falso negativo>`

### 4.6 Evidência

`images/01-ftp-medusa.png`

---

## 5. Cenário 2 — DVWA (web-form)

### 5.1 Estrutura do formulário (real)

```bash
$ curl -s http://192.168.56.101/dvwa/login.php | grep -E 'form|input'
<cole a saída real>
```

| Elemento | Valor encontrado |
| --- | --- |
| `action` | `<login.php>` |
| `method` | `<post>` |
| Campo de usuário | `<username>` |
| Campo de senha | `<password>` |
| Botão submit | `<Login>` |
| Token anti-CSRF | `<presente / ausente>` |

### 5.2 Comando executado

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

### 5.3 Nível de segurança do DVWA

`<Low / Medium / High>` — justificativa: `<ex.: no nível Medium o token anti-CSRF
está ativo, o que impede o Medusa; documentei isso como demonstração de defesa
eficaz>`

### 5.4 Saída (trecho real)

```text
<cole a saída do Medusa aqui>
```

### 5.5 Resultado

| Campo | Valor |
| --- | --- |
| Usuário focado | `<admin>` |
| Senhas testadas | `<24>` |
| **Credencial válida** | `<usuario>` / `<senha>` |
| Tempo total | `<X s>` |
| Token anti-CSRF interferiu? | `<sim/não>` — `<detalhe>` |

### 5.6 Teste com o verificador em Python

```bash
$ python3 scripts/dvwa_login_check.py --url http://192.168.56.101/dvwa \
    --usuario admin --lista wordlists/senhas.txt --confirmo-lab
<cole a saída real>
```

### 5.7 Dificuldades encontradas

`<ex.: DENY-SIGNAL errado fazia o Medusa reportar todos os logins como sucesso;
com o token ativo, nenhuma tentativa passava>`

### 5.8 Evidências

`images/02-dvwa-medusa.png`, `images/03-dvwa-apos-login.png`

---

## 6. Cenário 3 — SMB (password spraying)

### 6.1 Estratégia

```text
Senhas no laço EXTERNO (5), usuários no laço INTERNO (13)
  → 5 rodadas × 15 usuários = 75 logins
  → máximo de 5 falhas por conta (espaçadas por pausa de 2 s)
```

### 6.2 Comando executado

```bash
./scripts/smb_spray.sh --alvo 192.168.56.101 --confirmo-lab --verbose
```

### 6.3 Saída (trecho real)

```text
<cole a saída do script aqui>
```

### 6.4 Resultado

| Campo | Valor |
| --- | --- |
| Usuários testados | `<15>` |
| Senhas (rodadas) | `<5>` |
| Total de tentativas | `<75>` |
| **Credenciais válidas** | `<usuario>` / `<senha>` |
| Tempo total | `<X min>` |
| Contas bloqueadas durante o teste | `<0>` |

### 6.5 Validação do acesso

```bash
$ smbclient -L //192.168.56.101 -U <usuario>%<senha>
<cole a saída real>

$ smbclient //192.168.56.101/tmp -U <usuario>%<senha>
smb: \> ls
<cole a saída real>
```

### 6.6 Dificuldades encontradas

`<ex.: -t alto saturava o Samba e gerava falsos negativos; o módulo smbnt precisou
de -m GROUP:<dominio> em <situação>>`

### 6.7 Evidências

`images/04-enum4linux.png`, `images/05-smb-spray.png`, `images/06-smbclient-share.png`

---

## 7. Comparativo dos três cenários

| Critério | FTP | DVWA (web-form) | SMB (spraying) |
| --- | --- | --- | --- |
| Facilidade de execução | `<alta>` | `<média>` | `<média>` |
| Sensibilidade a ajustes | `<média (-c)>` | `<alta (FORM-DATA/DENY-SIGNAL)>` | `<média (-t, pausa)>` |
| Credencial encontrada | `<sim/não>` | `<sim/não>` | `<sim/não>` |
| Tempo até o primeiro acerto | `<X s>` | `<X s>` | `<X min>` |
| Barulho gerado (logs) | `<alto>` | `<alto>` | `<médio>` |
| Defesa mais eficaz | `<SFTP + sem anônimo>` | `<CSRF + rate limit + MFA>` | `<lockout + MFA + monitorar 4625>` |

---

## 8. Teste das mitigações (recomendado)

> Repita pelo menos um cenário **após** aplicar a mitigação, e registre a diferença.
> Este é o item que mais demonstra maturidade técnica no relatório.

| Cenário | Mitigação aplicada | Antes | Depois |
| --- | --- | --- | --- |
| FTP | `<max_login_fails=3 + Fail2ban>` | `<credencial em X s>` | `<bloqueado após 3 tentativas>` |
| DVWA | `<CSRF token + rate limit 5/min>` | `<credencial em X s>` | `<403 / 429>` |
| SMB | `<lockout 5 tentativas>` | `<credencial em X min>` | `<conta bloqueada, alerta gerado>` |

**O ataque foi detectado nos logs?** `<sim/não>` — `<qual log, qual evento>`

---

## 9. Conclusões

### Técnicas

`<3 a 5 parágrafos com as SUAS conclusões — use 04-reflexao.md como esqueleto>`

### Defensivas

`<o que você aplicaria primeiro em um ambiente real, e por quê>`

### Éticas

`<sua reflexão sobre escopo, autorização e responsabilidade>`

---

## 10. Anexos

| # | Arquivo | Descrição |
| --- | --- | --- |
| 01 | `images/01-ftp-medusa.png` | Execução do Medusa contra o FTP |
| 02 | `images/02-dvwa-medusa.png` | Execução contra o formulário do DVWA |
| 03 | `images/03-dvwa-apos-login.png` | Painel do DVWA autenticado |
| 04 | `images/04-enum4linux.png` | Enumeração SMB |
| 05 | `images/05-smb-spray.png` | Password spraying em execução |
| 06 | `images/06-smbclient-share.png` | Acesso ao share com a credencial obtida |
| 07 | `<nmap-saida.txt>` | Saída completa do Nmap (opcional) |

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
