#!/usr/bin/env bash
set -euo pipefail

# All metrics scale from the 3440x1440 reference design: vertical/size values
# follow the display height, horizontal placement follows the display width,
# so elements keep their proportions on any aspect ratio.
REF_WIDTH=3440
REF_HEIGHT=1440
VISIBLE_ROWS=5

RESOLUTION="${1:-${REF_WIDTH}x${REF_HEIGHT}}"
if [[ ! "${RESOLUTION}" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    printf 'Usage: %s [WIDTHxHEIGHT]  (default %sx%s)\n' "$0" "${REF_WIDTH}" "${REF_HEIGHT}" >&2
    exit 1
fi
W="${BASH_REMATCH[1]}"
H="${BASH_REMATCH[2]}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SVG="${ROOT_DIR}/src/background.svg"
CRT_OVERLAY_SVG="${ROOT_DIR}/src/crt-overlay.svg"
THEME_TEMPLATE="${ROOT_DIR}/src/theme.txt.in"
THEME_DIR="${ROOT_DIR}/theme"
HOST_RUN=()

if command -v flatpak-spawn >/dev/null 2>&1; then
    HOST_RUN=(flatpak-spawn --host)
fi

for source in \
    "${SOURCE_SVG}" \
    "${CRT_OVERLAY_SVG}" \
    "${THEME_TEMPLATE}" \
    "${ROOT_DIR}/src/icon-debian.svg" \
    "${ROOT_DIR}/src/icon-fedora.svg" \
    "${ROOT_DIR}/src/icon-linux.svg" \
    "${ROOT_DIR}/src/icon-settings.svg" \
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

# Round a reference value scaled by height (sizes) or width (horizontal layout).
scaled() { awk -v v="$1" -v h="${H}" -v r="${REF_HEIGHT}" 'BEGIN { printf "%d", (v * h / r) + 0.5 }'; }
hscaled() { awk -v v="$1" -v w="${W}" -v r="${REF_WIDTH}" 'BEGIN { printf "%d", (v * w / r) + 0.5 }'; }
at_least() { if (( $2 < $1 )); then printf '%d' "$1"; else printf '%d' "$2"; fi; }

FONT_SIZE="$(scaled 32)"
LABEL_H="$(scaled 50)"

ITEM_H="$(scaled 111)"
ITEM_SPACING="$(scaled 89)"
ICON_SIZE="$(scaled 86)"
ICON_SPACE="$(scaled 28)"
MENU_H=$(( VISIBLE_ROWS * ITEM_H + (VISIBLE_ROWS - 1) * ITEM_SPACING ))

# The frame surrounds the menu with one item_spacing of padding on every row edge.
FRAME_X="$(hscaled 530)"
FRAME_W=$(( W - 2 * FRAME_X ))
FRAME_H=$(( MENU_H + 2 * ITEM_SPACING ))
FRAME_Y=$(( (H - FRAME_H) / 2 ))
FRAME_RX="$(scaled 14)"
FRAME_STROKE="$(at_least 1 "$(scaled 2)")"
MENU_TOP=$(( FRAME_Y + ITEM_SPACING ))

HELP_FONT="$(scaled 24)"
HELP_CX=$(( W / 2 ))
HELP_Y1=$(( FRAME_Y + FRAME_H + $(scaled 78) ))
HELP_Y2=$(( FRAME_Y + FRAME_H + $(scaled 116) ))

SCAN_PITCH="$(at_least 3 "$(scaled 6)")"
SCAN_BLACK="$(at_least 1 "$(scaled 2)")"
SCAN_PINK="$(at_least 1 "$(scaled 1)")"

# Curved glass corners of the CRT: the dark fill bleeds past the canvas so the
# blur keeps corner tips solid while feathering the inner boundary.
CORNER_RX="$(scaled 156)"
CORNER_RY="$(scaled 118)"
CORNER_BLUR="$(at_least 1 "$(scaled 14)")"
BLEED=$(( 4 * CORNER_BLUR ))
BLEED_POS=$(( -BLEED ))
BLEED_W=$(( W + 2 * BLEED ))
BLEED_H=$(( H + 2 * BLEED ))

render_template() {
    local src="$1" dest="$2" name
    local sed_args=()
    for name in W H FRAME_X FRAME_Y FRAME_W FRAME_H FRAME_RX FRAME_STROKE \
        MENU_TOP MENU_H ITEM_H ITEM_SPACING ICON_SIZE ICON_SPACE LABEL_H \
        FONT_SIZE HELP_FONT HELP_CX HELP_Y1 HELP_Y2 \
        SCAN_PITCH SCAN_BLACK SCAN_PINK \
        CORNER_RX CORNER_RY CORNER_BLUR BLEED_POS BLEED_W BLEED_H; do
        sed_args+=(-e "s/@${name}@/${!name}/g")
    done
    sed "${sed_args[@]}" "${src}" > "${dest}"
    if grep -qE '@[A-Z_]+@' "${dest}"; then
        printf 'Unresolved tokens in %s:\n' "${dest}" >&2
        grep -oE '@[A-Z_]+@' "${dest}" | sort -u >&2
        exit 1
    fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${THEME_DIR}/icons"

render_template "${SOURCE_SVG}" "${TMP_DIR}/background.svg"
render_template "${CRT_OVERLAY_SVG}" "${TMP_DIR}/crt-overlay.svg"
render_template "${THEME_TEMPLATE}" "${THEME_DIR}/theme.txt"

rsvg-convert -w "${W}" -h "${H}" -o "${THEME_DIR}/background.png" "${TMP_DIR}/background.svg"
rsvg-convert -w "${W}" -h "${H}" -o "${THEME_DIR}/crt-overlay.png" "${TMP_DIR}/crt-overlay.svg"
rsvg-convert -w "$(scaled 110)" -h "$(scaled 110)" -o "${THEME_DIR}/icons/debian.png" "${ROOT_DIR}/src/icon-debian.svg"
rsvg-convert -w "$(scaled 110)" -h "$(scaled 107)" -o "${THEME_DIR}/icons/fedora.png" "${ROOT_DIR}/src/icon-fedora.svg"
rsvg-convert -w "$(scaled 110)" -h "$(scaled 110)" -o "${THEME_DIR}/icons/linux.png" "${ROOT_DIR}/src/icon-linux.svg"
rsvg-convert -w "$(scaled 110)" -h "$(scaled 110)" -o "${THEME_DIR}/icons/settings.png" "${ROOT_DIR}/src/icon-settings.svg"
rsvg-convert -w "$(scaled 108)" -h "$(scaled 108)" -o "${THEME_DIR}/icons/windows.png" "${ROOT_DIR}/src/icon-windows.svg"
rsvg-convert -w "$(at_least 1 "$(scaled 8)")" -h "$(at_least 1 "$(scaled 8)")" -o "${THEME_DIR}/select_c.png" "${ROOT_DIR}/src/select.svg"
rsvg-convert -w "$(scaled 54)" -h "${ITEM_H}" -o "${THEME_DIR}/select_w.png" "${ROOT_DIR}/src/select-w.svg"

cp -f "${THEME_DIR}/icons/linux.png" "${THEME_DIR}/icons/gnu-linux.png"
cp -f "${THEME_DIR}/icons/settings.png" "${THEME_DIR}/icons/options.png"
cp -f "${THEME_DIR}/icons/settings.png" "${THEME_DIR}/icons/submenu.png"

rm -f "${THEME_DIR}"/lucygrub-mono-*.pf2
"${HOST_RUN[@]}" grub2-mkfont \
    --verbose \
    --name='LucyGrub Mono' \
    --size="${FONT_SIZE}" \
    --output="${THEME_DIR}/lucygrub-mono.pf2" \
    "${FONT_FILE}"

chmod 0644 \
    "${THEME_DIR}/background.png" \
    "${THEME_DIR}/crt-overlay.png" \
    "${THEME_DIR}/select_c.png" \
    "${THEME_DIR}/select_w.png" \
    "${THEME_DIR}/lucygrub-mono.pf2" \
    "${THEME_DIR}/theme.txt" \
    "${THEME_DIR}/icons/"*.png

printf 'Built theme assets for %sx%s in %s\n' "${W}" "${H}" "${THEME_DIR}"
