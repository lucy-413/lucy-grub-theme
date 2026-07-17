#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SVG="${ROOT_DIR}/src/figma-export.svg"
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
    "${ROOT_DIR}/src/select.svg"; do
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

TMP_SVG="$(mktemp --suffix=.svg)"
trap 'rm -f "${TMP_SVG}"' EXIT

# Preserve the Figma frame, clear the placeholder rows/header, replace the
# typoed outlined footer, and offset narrow bands for horizontal CRT tearing.
sed \
    -e '/<svg /a\
<g id="crt-screen">' \
    -e '/<defs>/i\
<rect x="530" y="175" width="2380" height="1089" fill="black"/>\
<rect x="1390" y="95" width="660" height="62" fill="black"/>\
<rect x="900" y="1305" width="1640" height="105" fill="black"/>\
<text x="1720" y="1342" text-anchor="middle" fill="#A4133C" font-family="Source Code Pro" font-size="24">Use the ↑ and ↓ keys to select the highlighted entry.</text>\
<text x="1720" y="1380" text-anchor="middle" fill="#A4133C" font-family="Source Code Pro" font-size="24">Press Enter to boot. Press &apos;e&apos; to edit or &apos;c&apos; for the command line.</text>\
</g>\
<g>\
<rect y="115" width="3440" height="7" fill="black"/>\
<rect y="171" width="3440" height="5" fill="black"/>\
<rect y="1259" width="3440" height="8" fill="black"/>\
<rect y="1338" width="3440" height="6" fill="black"/>\
<rect y="374" width="3440" height="6" fill="black"/>\
<rect y="692" width="3440" height="4" fill="black"/>\
<rect y="1048" width="3440" height="7" fill="black"/>\
<use href="#crt-screen" transform="translate(12 0)" clip-path="url(#crt-shift-right)"/>\
<use href="#crt-screen" transform="translate(-8 0)" clip-path="url(#crt-shift-left)"/>\
</g>' \
    -e '/<defs>/a\
<clipPath id="crt-shift-right">\
<rect y="115" width="3440" height="7"/>\
<rect y="171" width="3440" height="5"/>\
<rect y="1259" width="3440" height="8"/>\
<rect y="1338" width="3440" height="6"/>\
</clipPath>\
<clipPath id="crt-shift-left">\
<rect y="374" width="3440" height="6"/>\
<rect y="692" width="3440" height="4"/>\
<rect y="1048" width="3440" height="7"/>\
</clipPath>' \
    "${SOURCE_SVG}" > "${TMP_SVG}"

rsvg-convert -w 3440 -h 1440 -o "${THEME_DIR}/background.png" "${TMP_SVG}"
rsvg-convert -w 3440 -h 1440 -o "${THEME_DIR}/crt-overlay.png" "${CRT_OVERLAY_SVG}"
rsvg-convert -w 110 -h 110 -o "${THEME_DIR}/icons/debian.png" "${ROOT_DIR}/src/icon-debian.svg"
rsvg-convert -w 110 -h 107 -o "${THEME_DIR}/icons/fedora.png" "${ROOT_DIR}/src/icon-fedora.svg"
rsvg-convert -w 110 -h 110 -o "${THEME_DIR}/icons/linux.png" "${ROOT_DIR}/src/icon-linux.svg"
rsvg-convert -w 108 -h 108 -o "${THEME_DIR}/icons/windows.png" "${ROOT_DIR}/src/icon-windows.svg"
rsvg-convert -w 8 -h 8 -o "${THEME_DIR}/select_c.png" "${ROOT_DIR}/src/select.svg"

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
    "${THEME_DIR}/lucygrub-mono-32.pf2" \
    "${THEME_DIR}/theme.txt" \
    "${THEME_DIR}/icons/"*.png

printf 'Built theme assets in %s\n' "${THEME_DIR}"
