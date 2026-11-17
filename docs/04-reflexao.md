# 04 — Reflexão: conceitos, ética e lições

> ⚠️ **Este texto é um rascunho para você reescrever com as suas palavras.**
> O objetivo da DIO é que a reflexão seja **sua**. Use esta estrutura como
> esqueleto, mas troque os exemplos pelos que você viveu no seu laboratório.

---

## 1. O que é, afinal, um ataque de força bruta

Força bruta é a tentativa sistemática de descobrir uma credencial testando
possibilidades. O termo cobre técnicas bem diferentes:

| Técnica | Estratégia | Exemplo no laboratório | Espaço de busca |
| --- | --- | --- | --- |
| **Força bruta pura** | Todas as combinações possíveis | `aaaa`, `aaab`, `aaac`... | Gigantesco (inviável além de ~8 caracteres) |
| **Dicionário** | Lista de senhas prováveis | `medusa -P wordlists/senhas.txt` | Pequeno e altamente eficaz |
| **Password spraying** | 1 senha fraca × muitos usuários | `scripts/smb_spray.sh` | Depende da política de lockout |
| **Credential stuffing** | Usuário:senha vazados de outro serviço | (não abordado) | Depende do reuso de senha |

A distinção mais importante do desafio é a **terceira linha**. O spraying não é
"força bruta mais lenta": é uma adaptação que **contorna especificamente** o
lockout — a defesa mais comum. Isso mostra algo essencial: **defesas isoladas
são contornadas; defesas em camadas não.**

---

## 2. O que eu aprendi sobre o Medusa

*(reescreva com as suas observações)*

- O Medusa é **modular**: a mesma ferramenta ataca FTP, web, SMB, SSH, MySQL...
  Só o `-M` e os `-m` mudam. Isso faz dele um bom objeto de estudo: você aprende
  **um** modelo mental e aplica em vários protocolos.
- Ele é **paralelo por padrão** (`-t`, `-T`), o que o torna rápido — e barulhento.
  Contra um Apache de 2009, `-t 100` derruba o serviço e produz **falsos
  negativos**, que são piores que "não funcionou": você conclui que a senha não
  está na lista, quando na verdade o alvo parou de responder.
- O **`-c`** (espera em µs para validar o socket) foi o detalhe mais inesperado.
  Sem `-c 1000`, o ataque ao vsftpd "falha" — não porque a senha está errada,
  mas porque a conexão morre entre as tentativas. É um exemplo perfeito de como
  a **mecânica de rede** importa tanto quanto a ferramenta.
- No **`web-form`**, a fragilidade é evidente: `FORM-DATA` na ordem errada,
  `DENY-SIGNAL` com o texto errado, ou um token anti-CSRF — qualquer um faz o
  ataque falhar silenciosamente (ou, pior, reportar tudo como sucesso).

---

## 3. O que eu aprendi sobre defesa

*(reescreva com as suas observações)*

Três conclusões que mudaram a minha forma de ver autenticação:

**1. A senha não é o componente mais frágil — o limite de tentativas é.**
Um sistema com senhas medianas, mas com `5 tentativas/minuto` e MFA, resiste a
todo este laboratório. Um sistema com senhas "complexas", mas sem limite de
tentativas, cai para um dicionário.

**2. Lockout permanente é uma faca de dois gumes.**
Ele bloqueia o atacante **e** o usuário legítimo. Pior: permite que um atacante
cause DoS de contas de propósito. A resposta correta é **lockout progressivo +
MFA + detecção**, não "bloquear para sempre".

**3. Detecção por padrão, não por evento.**
Um `4625` isolado é rotina (todo mundo digita a senha errada). Cinquenta `4625`
em trinta segundos, para **contas diferentes**, do **mesmo IP**, é ataque. A
diferença entre um SOC eficaz e um ineficaz está na correlação.

---

## 4. Ética e escopo — a parte que não é opcional

### 4.1 A linha entre estudo e crime

```text
Laboratório isolado, VMs próprias          →  estudo legítimo
Sistema do cliente, com contrato assinado  →  pentest legítimo
Bug bounty dentro do escopo publicado      →  pesquisa legítima
"Vou só testar a senha do vizinho"          →  CRIME
"É a rede da empresa, eu trabalho lá"       →  CRIME (sem autorização escrita)
```

No Brasil:

- **Lei 12.737/2012** (Carolina Dieckmann): invasão de dispositivo informático,
  pena de detenção + multa, **agravada** se houver obtenção de dados;
- **Lei 12.965/2014** (Marco Civil): dever de segurança e responsabilidade;
- **LGPD**: vazamento de dados pessoais gera sanções administrativas e
  responsabilidade civil.

Autorização **verbal** não serve. Precisa ser **escrita**, com escopo definido:
quais IPs, quais horários, quais técnicas permitidas, o que fazer se um dado
sensível for encontrado. Todo profissional assina um **contrato de pentest** com
uma cláusula de escopo — e respeitar esse escopo é parte do trabalho.

### 4.2 A autorização é do proprietário, não sua

"Tenho acesso ao sistema" ≠ "posso testar o sistema". Um funcionário com login
válido que executa brute force contra o próprio domínio, sem autorização, comete
uma violação — mesmo sem intenção maliciosa. Foi assim que profissionais já
perderam o emprego.

### 4.3 Responsabilidade sobre os dados

Se o laboratório for feito em uma cópia de dados reais (o que **não** é o caso
aqui), as credenciais descobertas são dados sensíveis e devem ser:

```text
✅ Armazenadas de forma segura ou destruídas após o relatório
✅ Nunca publicadas em repositório, chat ou print de tela
✅ Nunca reutilizadas em outro sistema
```

O `.gitignore` deste repositório exclui `logs/` exatamente por isso.

---

## 5. O que eu faria diferente no laboratório

*(espaço para a sua crítica honesta — este é o parágrafo que a DIO mais valoriza)*

Sugestões de tópicos:

- O que deu errado na primeira tentativa de cada cenário?
- Qual configuração consumiu mais tempo e por quê?
- O que eu faria em uma segunda rodada (ex.: aplicar as mitigações e repetir o
  ataque, medindo a diferença)?
- Que ferramenta eu testaria em seguida (Hydra, Ncrack, Patator) e por quê?
- Como eu documentaria isso para um cliente real (relatório executivo vs.
  relatório técnico)?

---

## 6. Conclusão

Um ataque de força bruta bem-sucedido não revela "um sistema inseguro" de forma
genérica — ele aponta **exatamente** onde a política de autenticação falhou:
senha padrão não trocada, ausência de limite de tentativas, ausência de MFA,
serviço exposto sem necessidade.

Esse é o valor real do exercício: ao executar o ataque **eu** consigo ver o que
o defensor precisa ver. E, na prática, as mitigações mais eficazes são as mais
baratas: **limitar tentativas, exigir MFA e monitorar padrões**. Nenhuma delas
depende de tecnologia de ponta — dependem de **saber que o risco existe**.

O conhecimento ofensivo, usado com autorização e ética, é o que permite construir
defesas que realmente funcionam.

---

## 7. Checklist de reflexão (para incluir no relatório)

```text
[ ] Expliquei a diferença entre brute force, dicionário, spraying e stuffing
[ ] Descrevi a mecânica do Medusa (módulos, -t, -c, FORM-DATA, DENY-SIGNAL)
[ ] Documentei os erros que cometi e como resolvi
[ ] Proposei mitigações específicas por serviço (FTP, web, SMB)
[ ] Expliquei por que MFA + rate limit são as defesas mais eficazes
[ ] Discuti a ética: escopo, autorização escrita e responsabilidade sobre dados
[ ] Relacionei com legislação aplicável (12.737, Marco Civil, LGPD)
[ ] Escrevi com as MINHAS palavras, não copiei este arquivo
```
