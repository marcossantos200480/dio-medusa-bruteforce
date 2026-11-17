# logs/ — Saídas do laboratório (NÃO versionadas)

> 🚫 **Esta pasta está no `.gitignore`.** Nada aqui é enviado ao GitHub — apenas
> este README e o `.gitkeep` são versionados.

## Por que não versionar

Os arquivos gerados aqui contêm **credenciais válidas em texto claro** (é
literalmente o resultado de um brute force bem-sucedido). Publicá-los em um
repositório público exporia senhas — mesmo que de um laboratório.

```text
❌ logs/20261117-2230-ftp/achados.csv          → credenciais
❌ logs/20261117-2230-smb-spray/medusa-*.txt   → credenciais
❌ qualquer *.log com "ACCOUNT FOUND"
```

## Estrutura gerada pelos scripts

```
logs/
├── README.md                        ← único arquivo versionado (junto com .gitkeep)
├── .gitkeep
│
├── 20261117-2230-smb-spray/         ← criado por scripts/smb_spray.sh
│   ├── spray.log                    ← log completo da execução
│   ├── medusa-senha-1.txt           ← saída bruta do Medusa por rodada
│   ├── medusa-senha-2.txt
│   ├── usuarios-limpo.txt           ← lista de usuários sem comentários
│   └── achados.csv                  ← ⚠ data_hora,senha,usuario,ip
│
└── ftp-resultado.txt                ← criado por medusa -O
```

## O que fazer com eles

```bash
# 1. Use para preencher docs/RELATORIO_MODELO.md
cat logs/*/achados.csv

# 2. Guarde as capturas de tela em images/ (essas SIM vão para o GitHub,
#    desde que não exponham credenciais reais)

# 3. Ao terminar, apague as saídas
rm -rf logs/2026*          # cuidado com o glob: confira antes com ls

# Ou, mais seguro, mova para fora do repositório
mv logs/20261117-2230-smb-spray ~/evidencias-lab/
```

## Se precisar versionar um log (caso raro)

Só faça isso se o log **não** contiver credenciais, e sempre de forma explícita:

```bash
git add -f logs/nmap-inicial.txt      # -f força, ignorando o .gitignore
```

> ⚠️ Antes de qualquer `git add -f`, rode `grep -iE 'password|senha|ACCOUNT FOUND'`
> no arquivo. Se aparecer algo, **não** versione.

## Segurança

```bash
# Permissões restritas na pasta
chmod 700 logs/

# Confira o que o git está ignorando
git status --ignored --short | grep logs

# Confira se nada sensível entrou no índice
git ls-files | grep -E '\.(log|csv)$'
```

Se um log com credencial for commitado **por acidente**, remova do histórico —
não basta apagar no commit seguinte (`git rm --cached`), o conteúdo continua no
histórico do Git. Nesse caso, o correto é tratar a credencial como comprometida,
trocá-la e limpar o histórico (`git filter-repo`).
