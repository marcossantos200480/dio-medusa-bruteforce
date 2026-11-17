# Wordlists didáticas — Medusa / DIO

Estas listas existem **apenas para o laboratório isolado**. Elas são curtas de
propósito: o objetivo do desafio é entender o **mecanismo** do brute force e do
password spraying, não quebrar senhas reais.

## Arquivos

| Arquivo | Para que serve | Usado por |
| --- | --- | --- |
| `usuarios.txt` | Usuários comuns + contas padrão do Metasploitable 2 (FTP) | `medusa -M ftp -U` |
| `senhas.txt` | Senhas fracas clássicas + padrões do Metasploitable | `medusa -M ftp -P` |
| `usuarios-smb.txt` | Usuários para enumeração/spraying SMB | `scripts/smb_spray.sh` |
| `senhas-spray.txt` | Poucas senhas para spraying (1 por rodada) | `scripts/smb_spray.sh` |

## Formato

- Uma entrada por linha.
- Linhas em branco são ignoradas.
- Linhas começando com `#` são comentários e também são ignoradas pelos scripts
  (`grep -vE '^[[:space:]]*(#|$)'`).

## Por que `senhas-spray.txt` é tão curta?

Password spraying funciona com **poucas senhas testadas contra muitos usuários**.
Uma lista curta + pausa entre tentativas é o que diferencia spraying de brute
force cego — e é exatamente o que evita bloquear todas as contas do domínio em
produção. No laboratório você pode aumentar a lista, mas mantenha a lógica:
**senha no laço externo**.

## ⚠️ Limite de escopo

Não adicione aqui senhas ou usuários reais de pessoas, empresas ou serviços.
Se precisar de listas maiores para estudo, use dicionários públicos e didáticos
(ex.: o `rockyou.txt` que já vem no Kali, em `/usr/share/wordlists/`) e
respeite a lei: testar credenciais em sistemas de terceiros é crime.
