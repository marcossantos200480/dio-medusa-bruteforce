# images/ — Capturas de tela do laboratório

Evidências da execução real do laboratório em **17/11/2026**, capturadas em
máquinas virtuais próprias, em rede host-only isolada.

## Arquivos

| Arquivo | O que mostra | Cenário |
| --- | --- | --- |
| [`00-topologia.jpg`](00-topologia.jpg) | VirtualBox com as VMs Kali Linux e Metasploitable em execução | ambiente |
| [`00-lab-metasploitable.jpg`](00-lab-metasploitable.jpg) | Console do Metasploitable 2 autenticado como `msfadmin` | ambiente |
| [`01-ftp-medusa.jpg`](01-ftp-medusa.jpg) | `medusa -M ftp` encontrando `user:user` e `msfadmin:msfadmin` | 1 — FTP |
| [`02-dvwa-medusa.jpg`](02-dvwa-medusa.jpg) | `medusa -M web-form` encontrando `admin:password` no DVWA | 2 — web |
| [`03-dvwa-apos-login.jpg`](03-dvwa-apos-login.jpg) | DVWA autenticado no navegador (validação manual da credencial) | 2 — web |
| [`04-enum4linux.jpg`](04-enum4linux.jpg) | `enum4linux -U` e `-P`: usuários e política de senha | 3 — SMB |
| [`05-smb-spray.jpg`](05-smb-spray.jpg) | `medusa -M smbnt` obtendo `ADMIN$ - Access Allowed` | 3 — SMB |
| [`06-smbclient-share.jpg`](06-smbclient-share.jpg) | Listagem do share `/tmp` com a credencial obtida | 3 — SMB |
| [`07-falso-positivo.jpg`](07-falso-positivo.jpg) | **Erro documentado:** falsos positivos com o módulo `http` | aprendizado |

## Por que existe o arquivo 07 (falso positivo)

O `07-falso-positivo.jpg` registra um **erro real** cometido durante o laboratório:
o uso de sintaxe inexistente (`PAGE:` / `FORM:` / `FAIL=`), que fez o Medusa cair
no módulo `http` e reportar **todas** as credenciais como válidas.

Ele está no repositório de propósito. Documentar como o erro foi identificado e
corrigido demonstra mais competência técnica do que mostrar apenas os acertos.
A análise completa está em [`../docs/04-reflexao.md`](../docs/04-reflexao.md).

## Especificações

| Propriedade | Valor |
| --- | --- |
| Resolução | 1920 × 1080 px |
| Formato | JPEG (qualidade 88, progressivo) |
| Tamanho médio | ~230 KB por arquivo |
| Peso total | ~2,0 MB |

O formato JPEG foi escolhido em vez de PNG porque as capturas originais somavam
6,5 MB — o JPEG entrega a mesma legibilidade de texto com um terço do tamanho,
o que mantém o clone do repositório rápido.

## Adicionando novas evidências

Se você reexecutar o laboratório e quiser atualizar uma imagem:

```bash
# 1. Capture com o capturador de tela
scrot -q 92 01-ftp-medusa.png

# 2. Converta para JPEG otimizado (mantendo a legibilidade)
convert 01-ftp-medusa.png -quality 88 -interlace Plane 01-ftp-medusa.jpg
rm 01-ftp-medusa.png

# 3. Confira o tamanho (ideal: entre 150 KB e 400 KB)
du -h 01-ftp-medusa.jpg

# 4. Confira a legibilidade abrindo o arquivo antes de commitar
xdg-open 01-ftp-medusa.jpg
```

> 💡 Prefira capturar apenas a janela do terminal (`scrot -u` ou a tecla de
> captura de janela) em vez da tela inteira: o texto fica maior e mais legível.

## ⚠️ Antes de publicar uma nova captura

```text
[ ] A imagem é do SEU laboratório (VM própria, IP 192.168.56.x)
[ ] Não há dados pessoais, nomes de empresas, e-mails ou dados de clientes
[ ] Não há credenciais reais (somente as do Metasploitable/DVWA, que são fictícias)
[ ] A barra de tarefas/navegador não expõe informação sensível
[ ] O arquivo tem menos de 500 KB
```

Se um log com credencial for commitado por acidente, não basta apagá-lo no commit
seguinte: o conteúdo permanece no histórico do Git. Nesse caso, trate a credencial
como comprometida, troque-a e limpe o histórico com `git filter-repo`.
