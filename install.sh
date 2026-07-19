#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    printf 'Run this installer with sudo: sudo ./install.sh\n' >&2
    exit 1
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${ROOT_DIR}/theme"
THEME_NAME="lucygrub-terminal"
TARGET_DIR="/boot/grub2/themes/${THEME_NAME}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/boot/grub2/theme-backups/${THEME_NAME}-${STAMP}"
DEFAULTS_FILE="/etc/default/grub"
GRUB_CFG="/boot/grub2/grub.cfg"

for file in theme.txt background.png crt-overlay.png select_c.png select_w.png lucygrub-mono.pf2; do
    if [[ ! -f "${SOURCE_DIR}/${file}" ]]; then
        printf 'Missing built asset: %s\nRun ./build.sh first.\n' "${SOURCE_DIR}/${file}" >&2
        exit 1
    fi
done

# build.sh stamps theme.txt with the resolution the assets were rendered for.
RESOLUTION="$(sed -nE 's/^# resolution: ([0-9]+x[0-9]+).*$/\1/p' "${SOURCE_DIR}/theme.txt" | head -n1)"
if [[ -z "${RESOLUTION}" ]]; then
    printf 'No resolution stamp in %s.\nRun ./build.sh [WIDTHxHEIGHT] first.\n' "${SOURCE_DIR}/theme.txt" >&2
    exit 1
fi

for command in grub2-mkconfig grub2-script-check grub2-editenv; do
    command -v "${command}" >/dev/null || {
        printf 'Required command not found: %s\n' "${command}" >&2
        exit 1
    }
done

install -d -m 0700 "${BACKUP_DIR}"
cp -a "${DEFAULTS_FILE}" "${BACKUP_DIR}/etc-default-grub"
if [[ -f "${GRUB_CFG}" ]]; then
    cp -a "${GRUB_CFG}" "${BACKUP_DIR}/grub.cfg"
fi

OLD_THEME="$(grep -E "^[[:space:]]*GRUB_THEME=" "${DEFAULTS_FILE}" | tail -n1 | cut -d= -f2- | tr -d "\"")"
if [[ -n "${OLD_THEME}" && -e "${OLD_THEME}" ]]; then
    cp -a "$(dirname -- "${OLD_THEME}")" "${BACKUP_DIR}/previous-theme"
fi

install -d -m 0755 "${TARGET_DIR}/icons"
rm -f "${TARGET_DIR}"/lucygrub-mono-*.pf2
install -m 0644 \
    "${SOURCE_DIR}/theme.txt" \
    "${SOURCE_DIR}/background.png" \
    "${SOURCE_DIR}/crt-overlay.png" \
    "${SOURCE_DIR}/select_c.png" \
    "${SOURCE_DIR}/select_w.png" \
    "${SOURCE_DIR}/lucygrub-mono.pf2" \
    "${TARGET_DIR}/"
install -m 0644 "${SOURCE_DIR}/icons/"*.png "${TARGET_DIR}/icons/"

set_grub_value() {
    local key="$1"
    local value="$2"
    local escaped
    escaped="$(printf '%s' "${value}" | sed 's/[&|]/\\&/g')"

    if grep -qE "^[[:space:]]*${key}=" "${DEFAULTS_FILE}"; then
        sed -i -E "s|^[[:space:]]*${key}=.*|${key}=${escaped}|" "${DEFAULTS_FILE}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${DEFAULTS_FILE}"
    fi
}

set_grub_value GRUB_THEME '"/boot/grub2/themes/lucygrub-terminal/theme.txt"'
set_grub_value GRUB_FONT '"/boot/grub2/themes/lucygrub-terminal/lucygrub-mono.pf2"'
set_grub_value GRUB_TERMINAL_OUTPUT '"gfxterm"'
set_grub_value GRUB_GFXMODE "\"${RESOLUTION}x32,${RESOLUTION},auto\""
set_grub_value GRUB_TIMEOUT_STYLE '"menu"'

grub2-editenv - unset menu_auto_hide
grub2-mkconfig -o "${GRUB_CFG}"
grub2-script-check "${GRUB_CFG}"

NATIVE_MODE="$(cat /sys/class/drm/card*/modes 2>/dev/null | head -n1 || true)"
if [[ -n "${NATIVE_MODE}" && "${NATIVE_MODE}" != "${RESOLUTION}" ]]; then
    printf '\nNote: the display reports %s but the theme was built for %s.\n' "${NATIVE_MODE}" "${RESOLUTION}"
    printf 'For a pixel-perfect fit run: ./build.sh %s && sudo ./install.sh\n' "${NATIVE_MODE}"
fi

printf '\nInstalled %s for %s.\n' "${THEME_NAME}" "${RESOLUTION}"
printf 'Backup: %s\n' "${BACKUP_DIR}"
printf 'Reboot when ready. If %s is unavailable in UEFI, GRUB will use the next mode.\n' "${RESOLUTION}"
printf '\nRollback commands:\n'
printf '  sudo cp %q /etc/default/grub\n' "${BACKUP_DIR}/etc-default-grub"
printf '  sudo grub2-mkconfig -o /boot/grub2/grub.cfg\n'
