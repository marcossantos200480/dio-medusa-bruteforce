# images/ — Capturas de tela do laboratório

Esta pasta guarda as **suas** evidências visuais. O repositório publicado não
inclui capturas de terceiros nem resultados fabricados: as imagens entram aqui
depois que você executar os cenários.

## ⚠️ Antes de subir uma captura de tela

```text
[ ] A imagem é do SEU laboratório (VM própria, IP 192.168.56.x)
[ ] Não há dados pessoais, nomes de empresas, e-mails ou dados de clientes
[ ] Não há credenciais reais (somente as do Metasploitable/DVWA, que são fictícias)
[ ] A barra de tarefas/navegador não expõe informação sensível
[ ] O tamanho do arquivo é razoável (< 1 MB; prefira PNG otimizado ou JPG)
```

## Convenção de nomes

Use os nomes exatos abaixo — eles já estão referenciados no `README.md` e no
`docs/RELATORIO_MODELO.md`, então não é preciso editar nada além de salvar os
arquivos.

| Arquivo | O que deve mostrar | Cenário |
| --- | --- | --- |
| `01-ftp-medusa.png` | Terminal do Kali com o Medusa rodando contra o FTP e a linha `ACCOUNT FOUND` | 1 |
| `02-dvwa-medusa.png` | Medusa com `-M web-form` contra o `login.php` | 2 |
| `03-dvwa-apos-login.png` | Painel do DVWA já autenticado (prova de acesso) | 2 |
| `04-enum4linux.png` | Enumeração SMB, destacando a lista de usuários e a política de senha | 3 |
| `05-smb-spray.png` | Saída do `scripts/smb_spray.sh` (ou das rodadas manuais) | 3 |
| `06-smbclient-share.png` | `smbclient` listando um share com a credencial descoberta | 3 |
| `00-topologia.png` | *(opcional)* Print da tela do VirtualBox com as duas VMs na rede host-only | — |
| `07-mitigacao.png` | *(opcional)* Fail2ban/rate limit bloqueando o ataque | — |

## Como capturar bem

**Terminal (Linux/Kali):**

```bash
# Captura da janela ativa
gnome-screenshot -w -f images/01-ftp-medusa.png

# Ou com área selecionável (mais controle)
gnome-screenshot -a -f images/01-ftp-medusa.png

# Alternativa: Spectacle (KDE) ou Flameshot
sudo apt install -y flameshot && flameshot gui
```

**Dicas que fazem diferença no relatório:**

- Aumente a fonte do terminal antes de capturar (`Ctrl+Shift++`) — legibilidade
  conta pontos;
- Capture a **linha de comando completa** (é a prova do que foi executado);
- Inclua a linha `ACCOUNT FOUND` / `SUCCESS` **e** o prompt do shell;
- Se a saída for longa, capture o início (comando) e o final (resultado);
- Prefira PNG para texto de terminal (JPG cria artefatos nas letras).

**Redija/borre se necessário:**

```bash
# Borrar uma região com o Flameshot (tecla de blur) ou ImageMagick:
convert imagem.png -fill black -draw "rectangle 0,0 200,30" imagem-editada.png
```

## Verificação

Como o `README.md` referencia estes arquivos, imagens ausentes aparecem como
ícone quebrado no GitHub. Para conferir quais faltam:

```bash
for f in 01-ftp-medusa 02-dvwa-medusa 03-dvwa-apos-login \
         04-enum4linux 05-smb-spray 06-smbclient-share; do
  [[ -f "images/$f.png" ]] && echo "ok   $f.png" || echo "FALTA $f.png"
done
```

> O `.gitkeep` mantém esta pasta no versionamento mesmo enquanto estiver vazia.
> Remova-o quando adicionar as imagens (opcional).
