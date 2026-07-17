# LucyGRUB terminal theme

A GRUB 2 theme targeting a 3440x1440 ultrawide display. It combines a black/crimson terminal layout with scanlines, faint signal dropout, and narrow horizontal distortion bands while keeping GRUB's boot menu fully live.

## Build

The build requires `rsvg-convert`, `fc-match`, `grub2-mkfont`, and Source Code Pro Regular.

```bash
./build.sh
```

Editable SVG sources live under `src/`; ready-to-install assets live under `theme/`. The generated theme assets are intentionally tracked so installation does not require the build toolchain.

The Debian and generic Linux SVGs are rasterized to GRUB-compatible PNGs. Generic `linux` and `gnu-linux` menu classes share the Tux fallback, while Fedora, Debian, and Windows use their own icons.

## Install on Fedora

```bash
sudo ./install.sh
```

The installer:

- saves `/etc/default/grub`, the generated `grub.cfg`, and the previous theme under `/boot/grub2/theme-backups/`;
- installs to `/boot/grub2/themes/lucygrub-terminal/`;
- enables `gfxterm`, the theme, the custom font, and a safe graphics-mode fallback chain;
- unhides Fedora's GRUB menu;
- regenerates and syntax-checks `/boot/grub2/grub.cfg`.

Do not generate GRUB configuration into `/boot/efi/EFI/fedora/grub.cfg` on modern Fedora.

## Font alternatives

- **IBM Plex Mono Regular** — best polished match for the current composition.
- **Terminus** — sharpest retro/firmware look.
- **JetBrains Mono Nerd Font** — modern, heavier, and already installed locally.
- **Source Code Pro Regular** — current default; clean and highly readable.

After changing the font source in `build.sh`, also update the exact internal font name in `theme/theme.txt`. The name is printed by `grub2-mkfont --verbose`.
