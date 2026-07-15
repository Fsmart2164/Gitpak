#!/bin/fish
sudo meson setup build --buildtype release
sudo meson compile -C build
sudo meson install -C build
