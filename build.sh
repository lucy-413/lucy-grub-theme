#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SVG="${ROOT_DIR}/src/background.svg"
CRT_OVERLAY_SVG="${ROOT_DIR}/src/crt-overlay.svg"
THEME_DIR="${ROOT_DIR}/theme"
HOST_RUN=()

if command -v flatpak-spawn >/dev/null 2>&1; then
    HOST_RUN=(flatpak-spawn --host)
fi

for source in \
    "${SOURCE_SVG}" \
    "${CRT_OVERLAY_SVG}" \
    "${ROOT_DIR}/src/icon-debian.svg" \
    "${ROOT_DIR}/src/icon-fedora.svg" \
    "${ROOT_DIR}/src/icon-linux.svg" \
    "${ROOT_DIR}/src/icon-windows.svg" \
    "${ROOT_DIR}/src/select.svg" \
    "${ROOT_DIR}/src/select-w.svg"; do
    if [[ ! -f "${source}" ]]; then
        printf 'Missing %s\n' "${source}" >&2
        exit 1
    fi
done

if ! command -v rsvg-convert >/dev/null 2>&1; then
    printf 'rsvg-convert is required to build the PNG assets.\n' >&2
    exit 1
fi

FONT_FILE="$(${HOST_RUN[@]} fc-match -f '%{file}\n' 'Source Code Pro:style=Regular' | head -n1)"
if [[ -z "${FONT_FILE}" ]]; then
    printf 'Source Code Pro Regular was not found.\n' >&2
    exit 1
fi

mkdir -p "${THEME_DIR}/icons"

rsvg-convert -w 3440 -h 1440 -o "${THEME_DIR}/background.png" "${SOURCE_SVG}"
rsvg-convert -w 3440 -h 1440 -o "${THEME_DIR}/crt-overlay.png" "${CRT_OVERLAY_SVG}"
rsvg-convert -w 110 -h 110 -o "${THEME_DIR}/icons/debian.png" "${ROOT_DIR}/src/icon-debian.svg"
rsvg-convert -w 110 -h 107 -o "${THEME_DIR}/icons/fedora.png" "${ROOT_DIR}/src/icon-fedora.svg"
rsvg-convert -w 110 -h 110 -o "${THEME_DIR}/icons/linux.png" "${ROOT_DIR}/src/icon-linux.svg"
rsvg-convert -w 108 -h 108 -o "${THEME_DIR}/icons/windows.png" "${ROOT_DIR}/src/icon-windows.svg"
rsvg-convert -w 8 -h 8 -o "${THEME_DIR}/select_c.png" "${ROOT_DIR}/src/select.svg"
rsvg-convert -w 54 -h 111 -o "${THEME_DIR}/select_w.png" "${ROOT_DIR}/src/select-w.svg"

cp -f "${THEME_DIR}/icons/linux.png" "${THEME_DIR}/icons/gnu-linux.png"

"${HOST_RUN[@]}" grub2-mkfont \
    --verbose \
    --name='LucyGrub Mono' \
    --size=32 \
    --output="${THEME_DIR}/lucygrub-mono-32.pf2" \
    "${FONT_FILE}"

chmod 0644 \
    "${THEME_DIR}/background.png" \
    "${THEME_DIR}/crt-overlay.png" \
    "${THEME_DIR}/select_c.png" \
    "${THEME_DIR}/select_w.png" \
    "${THEME_DIR}/lucygrub-mono-32.pf2" \
    "${THEME_DIR}/theme.txt" \
    "${THEME_DIR}/icons/"*.png

printf 'Built theme assets in %s\n' "${THEME_DIR}"
