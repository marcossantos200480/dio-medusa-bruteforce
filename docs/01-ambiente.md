# 01 — Montagem do ambiente de laboratório

> Guia para construir as duas VMs do desafio em **VirtualBox**, com rede isolada
> *host-only*, e garantir que nenhum teste saia da caixa.

---

## 1. Por que isolar?

O laboratório usa duas máquinas virtuais:

| VM | Papel | Sistema |
| --- | --- | --- |
| **Kali Linux** | Atacante | Kali 2024.x |
| **Metasploitable 2** | Alvo vulnerável | Ubuntu 8.04 (deliberadamente inseguro) |

O Metasploitable é **propositalmente inseguro** — ele tem backdoors, serviços
antigos e senhas padrão. Se ele tiver qualquer rota para a internet ou para a
rede da sua casa/empresa, você cria um **risco real**: existem scanners na
internet que encontram Metasploitable exposto em minutos.

Por isso o adaptador de rede dos dois é **host-only**: as VMs conversam entre si
e com o host, e **nada mais**.

---

## 2. Requisitos

| Item | Mínimo | Recomendado |
| --- | --- | --- |
| RAM | 4 GB | 8 GB |
| Disco livre | 20 GB | 30 GB |
| CPU | 2 núcleos com VT-x/AMD-V | 4 núcleos |
| Hypervisor | VirtualBox 7.x | VirtualBox 7.0.x |
| Rede | Nenhuma | Nenhuma |

Verifique se a virtualização está habilitada na BIOS/UEFI. No Linux:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo    # > 0 = habilitado
```

---

## 3. Download das imagens

### Kali Linux

1. <https://www.kali.org/get-kali/#kali-virtual-machines>
2. Baixe o **VirtualBox image** (`.7z`), extraia e importe o `.ova`.

### Metasploitable 2

1. <https://docs.rapid7.com/metasploit/metasploitable-2/>
2. Baixe o `.zip`, extraia e abra o `.vmx` diretamente — o Metasploitable 2 é um
   appliance antigo, distribuído como ZIP (não OVA).

> 💡 As imagens rodam com usuário/senha padrão **`msfadmin` / `msfadmin`**.
> Isso é intencional no laboratório — e é exatamente o que o desafio explora.

---

## 4. Criar a rede host-only

**VirtualBox → Arquivo → Gerenciador de Rede → aba "Redes somente para host" (Host-only)**

1. Clique em **Criar** (botão "+").
2. Deixe o padrão:
   - Nome: `vboxnet0`
   - IPv4: `192.168.56.1`
   - Máscara: `255.255.255.0`
   - DHCP: **desabilitado** (usaremos IPs fixos — mais previsível)
3. Clique em **Aplicar** e feche.

> ⚠️ No **macOS** com VirtualBox 7, a rede host-only pode precisar ser habilitada
> manualmente:
> `sudo VBoxManage hostonlyif create`
>
> No **Windows**, se a criação falhar, verifique se o adaptador
> "VirtualBox Host-Only Ethernet Adapter" apareceu em "Adaptadores de Rede".

---

## 5. Configurar a VM atacante (Kali)

Com a VM **desligada**:

**Configurações → Rede → Adaptador 1**

| Campo | Valor |
| --- | --- |
| Habilitado | ✅ |
| Conectado a | **Rede somente para host (Host-only)** |
| Nome | `vboxnet0` |
| Modo promíscuo | Permitir tudo |

**Configurações → Sistema → Placa-mãe**: RAM 3072 MB, 2 vCPU.

Confirme que **não** existe um Adaptador 2 com NAT. Se existir, **desabilite**:
o adaptador NAT é a porta pela qual o tráfego sairia para a internet.

### IP fixo dentro do Kali

```bash
# Identificar a interface (normalmente eth0)
ip -4 -brief addr

# Editar a configuração do NetworkManager
sudo nmcli connection modify "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.56.102/24 \
  ipv4.gateway "" \
  ipv4.dns ""

sudo nmcli connection up "Wired connection 1"
ip -4 -brief addr        # deve mostrar 192.168.56.102/24
```

Verifique que **não há rota padrão**:

```bash
ip route
# Esperado: apenas 192.168.56.0/24 dev eth0  (SEM "default via ...")
```

Se aparecer `default via ...`, o isolamento está quebrado — desligue o adaptador
NAT e repita.

---

## 6. Configurar a VM alvo (Metasploitable 2)

Com a VM **desligada**:

**Configurações → Rede → Adaptador 1**

| Campo | Valor |
| --- | --- |
| Habilitado | ✅ |
| Conectado a | **Rede somente para host (Host-only)** |
| Nome | `vboxnet0` |

**Configurações → Sistema**: RAM 512–1024 MB, 1 vCPU (não aloque mais: o sistema
é de 2009 e não usa).

### IP fixo dentro do Metasploitable

Login: **`msfadmin` / `msfadmin`**

```bash
sudo su -
# O Metasploitable 2 usa /etc/network/interfaces
nano /etc/network/interfaces
```

Conteúdo:

```text
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.56.101
    netmask 255.255.255.0
    # SEM gateway, SEM dns-nameservers  → isolamento
```

Aplique:

```bash
/etc/init.d/networking restart
ifconfig eth0            # deve mostrar 192.168.56.101
```

### Confirmar que os serviços estão no ar

```bash
netstat -tlnp | grep -E ':(21|80|139|445) '
```

Saída esperada (resumida):

```text
tcp 0 0 0.0.0.0:21     LISTEN  vsftpd
tcp 0 0 0.0.0.0:80     LISTEN  apache2
tcp 0 0 0.0.0.0:139    LISTEN  smbd
tcp 0 0 0.0.0.0:445    LISTEN  smbd
```

Se algum não estiver escutando:

```bash
sudo /etc/init.d/vsftpd restart
sudo /etc/init.d/apache2 restart
sudo /etc/init.d/samba restart
```

---

## 7. Validar a comunicação entre as VMs

**Do Kali:**

```bash
# 1. O alvo responde?
ping -c 3 192.168.56.101

# 2. As portas do cenário estão abertas?
nmap -Pn -p 21,80,139,445 192.168.56.101

# 3. O DVWA carrega?
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://192.168.56.101/dvwa/
```

Resultado esperado: `HTTP 200` (ou `302` para `login.php`).

**Teste de isolamento (deve FALHAR de propósito):**

```bash
ping -c 2 8.8.8.8
# Esperado: "Network is unreachable" ou timeout total
```

Se o ping para 8.8.8.8 funcionar, **pare** e corrija a rede antes de continuar:
o laboratório não está isolado.

> ✅ O script `scripts/preflight_lab.sh` automatiza todas essas checagens:
> ```bash
> ./scripts/preflight_lab.sh --alvo 192.168.56.101 --confirmo-lab -v
> ```

---

## 8. Snapshots — o passo mais importante

Antes de **cada** cenário, com as VMs desligadas:

**VirtualBox → selecionar VM → Máquina → Tirar Snapshot** → nome: `limpo-pré-cenario-1`

Nomes sugeridos:

| Snapshot | Quando |
| --- | --- |
| `limpo-instalacao` | Após montar e validar a rede |
| `pre-cenario-1-ftp` | Antes do FTP |
| `pre-cenario-2-dvwa` | Antes do DVWA |
| `pre-cenario-3-smb` | Antes do SMB |

Depois de cada cenário: **Máquina → Reverter para Snapshot**.

Por quê? O FTP do vsftpd pode bloquear conexões após várias falhas, o Samba pode
entrar em estado inconsistente e o DVWA guarda sessões. Reverter garante que os
três cenários rodem nas **mesmas condições**, o que torna os resultados comparáveis.

---

## 9. Checklist final antes de atacar

```text
[ ] Kali com IP 192.168.56.102/24 e SEM rota padrão
[ ] Metasploitable com IP 192.168.56.101/24 e SEM gateway
[ ] ping entre as VMs funciona
[ ] ping para 8.8.8.8 FALHA (isolamento confirmado)
[ ] nmap mostra 21, 80, 139, 445 abertas no alvo
[ ] DVWA acessível em http://192.168.56.101/dvwa/
[ ] medusa instalado e módulos ftp/web-form/smbnt presentes
[ ] wordlists do repositório revisadas
[ ] snapshot tirado nas duas VMs
[ ] ./scripts/preflight_lab.sh --alvo 192.168.56.101 --confirmo-lab  → 0 falhas
```

---

## 10. Solução de problemas

| Sintoma | Causa provável | Solução |
| --- | --- | --- |
| VMs não se veem | Adaptadores em redes diferentes | Confirme `vboxnet0` nas duas |
| `ping 8.8.8.8` funciona | Adaptador NAT ativo | Desabilite o Adaptador 2 |
| Metasploitable sem rede | Configuração em `/etc/network/interfaces` | Revise o bloco `eth0` |
| DVWA retorna 404 | Caminho errado | Use `http://IP/dvwa/` (com barra final) |
| `medusa` não encontrado | Pacote ausente | `sudo apt install -y medusa` |
| Medusa "connection refused" no FTP | vsftpd derrubou a conexão | Adicione `-c 1000` |
| `web-form` sempre "sucesso" | `DENY-SIGNAL` errado | Confira a string exata da página de falha |
| Kali sem interface após importar | MAC diferente do `.ova` | `sudo dhclient eth0` ou redefina o IP |
