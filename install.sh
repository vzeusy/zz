#!/usr/bin/env bash
set -Eeuo pipefail
OWNER="luantec44"; REPO="Space-proto-xhttp-"; BRANCH="main"; VERSION="0.5.8.0"
BASE="https://raw.githubusercontent.com/${OWNER}/${REPO}/${BRANCH}"
TELEMETRY_URL="${SPACE_TELEMETRY_URL:-https://monitor.equipetech.online/api/v1/install}"
telemetry_json_escape(){ local s="${1:-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/ }"; s="${s//$'\r'/ }"; printf '%s' "$s"; }
send_install_telemetry(){
  [[ "${SPACE_TELEMETRY:-1}" != "0" ]] || return 0
  local d=/etc/space-telemetry idf=/etc/space-telemetry/host-id iid osn kernel arch
  umask 077; mkdir -p "$d" 2>/dev/null || return 0
  if [[ ! -s "$idf" ]]; then cat /proc/sys/kernel/random/uuid > "$idf" 2>/dev/null || return 0; fi
  iid="$(cat "$idf" 2>/dev/null || true)"; [[ -n "$iid" ]] || return 0
  osn="unknown"; if [[ -r /etc/os-release ]]; then . /etc/os-release; osn="${PRETTY_NAME:-${NAME:-Linux}}"; fi
  kernel="$(uname -r 2>/dev/null || true)"; arch="$(uname -m 2>/dev/null || true)"
  curl -fsS --connect-timeout 2 --max-time 5 -X POST "$TELEMETRY_URL" -H 'Content-Type: application/json' --data-binary "{\"install_id\":\"$(telemetry_json_escape "$iid")\",\"product\":\"space-proto\",\"version\":\"0.5.8.0\",\"arch\":\"$(telemetry_json_escape "$arch")\",\"os\":\"$(telemetry_json_escape "$osn")\",\"kernel\":\"$(telemetry_json_escape "$kernel")\"}" >/dev/null 2>&1 || true
}
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "ERRO: execute como root." >&2; exit 1; }
case "$(uname -m)" in x86_64|amd64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; *) echo "ERRO: arquitetura não suportada: $(uname -m). Use amd64 ou arm64." >&2; exit 1 ;; esac
command -v curl >/dev/null 2>&1 || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates; }
TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT
PKG="space-proto-v${VERSION}-${ARCH}.tar.gz"
echo "Baixando SSHPRO SPACE PROTO v${VERSION} (${ARCH})..."
echo "Contagem: UUID aleatório + IP de origem + versão/arquitetura/SO. Desative com SPACE_TELEMETRY=0."
curl -fL --retry 4 --connect-timeout 15 "${BASE}/dist/${PKG}" -o "$TMPDIR/$PKG"
curl -fsSL --retry 3 "${BASE}/SHA256SUMS" -o "$TMPDIR/SHA256SUMS"
EXPECTED="$(awk -v f="dist/${PKG}" '$2==f{print $1}' "$TMPDIR/SHA256SUMS" | head -n1)"; [[ -n "$EXPECTED" ]] || { echo "ERRO: checksum não encontrado para ${PKG}." >&2; exit 1; }
ACTUAL="$(sha256sum "$TMPDIR/$PKG" | awk '{print $1}')"; [[ "$ACTUAL" == "$EXPECTED" ]] || { echo "ERRO: SHA-256 inválido. Instalação cancelada." >&2; exit 1; }
tar -xzf "$TMPDIR/$PKG" -C "$TMPDIR"; cd "$TMPDIR/space-proto-v${VERSION}"; bash ./install.sh
send_install_telemetry
echo; echo "SPACE PROTO v${VERSION} instalado/atualizado com sucesso."; echo "Desenvolvedor: @luantech"; echo "Menu: spaceproto"; echo "Controle: spacectl status"; echo "Instalação registrada no contador quando a API está disponível."
