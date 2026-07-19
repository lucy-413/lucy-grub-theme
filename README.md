# LucyGRUB terminal theme

A black/crimson GRUB theme.

## Build

```sh
./build.sh              # reference resolution, 3440x1440
./build.sh 1920x1080    # or any WIDTHxHEIGHT
```

Assets are generated for the exact resolution you pass, so nothing is
stretched at boot: sizes (font, icons, menu rows, scanlines, CRT edge)
scale with the display height, horizontal placement follows the display
width. The 3440x1440 design in `src/` is the reference; edit the
templates there, not the generated files in `theme/`.

## Install

```sh
sudo ./install.sh
```

Installs the last-built theme and points `GRUB_GFXMODE` at its
resolution. It warns if the connected display reports a different
native mode than the one the theme was built for.
