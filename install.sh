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

for file in theme.txt background.png crt-overlay.png select_c.png lucygrub-mono-32.pf2; do
    if [[ ! -f "${SOURCE_DIR}/${file}" ]]; then
        printf 'Missing built asset: %s\nRun ./build.sh first.\n' "${SOURCE_DIR}/${file}" >&2
        exit 1
    fi
done

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
install -m 0644 \
    "${SOURCE_DIR}/theme.txt" \
    "${SOURCE_DIR}/background.png" \
    "${SOURCE_DIR}/crt-overlay.png" \
    "${SOURCE_DIR}/select_c.png" \
    "${SOURCE_DIR}/lucygrub-mono-32.pf2" \
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
set_grub_value GRUB_FONT '"/boot/grub2/themes/lucygrub-terminal/lucygrub-mono-32.pf2"'
set_grub_value GRUB_TERMINAL_OUTPUT '"gfxterm"'
set_grub_value GRUB_GFXMODE '"3440x1440x32,3440x1440,2560x1080,2560x1440,1920x1080,auto"'
set_grub_value GRUB_TIMEOUT_STYLE '"menu"'

grub2-editenv - unset menu_auto_hide
grub2-mkconfig -o "${GRUB_CFG}"
grub2-script-check "${GRUB_CFG}"

printf '\nInstalled %s.\n' "${THEME_NAME}"
printf 'Backup: %s\n' "${BACKUP_DIR}"
printf 'Reboot when ready. If 3440x1440 is unavailable in UEFI, GRUB will use the next mode.\n'
printf '\nRollback commands:\n'
printf '  sudo cp %q /etc/default/grub\n' "${BACKUP_DIR}/etc-default-grub"
printf '  sudo grub2-mkconfig -o /boot/grub2/grub.cfg\n'
