#!/bin/fish
git clone https://github.com/ErikReider/SwayOSD
cd SwayOSD
### git repo cloning ^ do not change ###

sudo meson setup build --buildtype release
sudo meson compile -C build
sudo meson install -C build

### clearing used data \/ do not change ###
cd /home/freddie/Projects/Gitpak/Repos
sudo rm -rf SwayOSD
