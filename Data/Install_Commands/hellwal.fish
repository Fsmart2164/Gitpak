#!/bin/fish
git clone https://github.com/danihek/hellwal
cd hellwal
### git repo cloning ^ do not change ###

sudo make install

### clearing used data \/ do not change ###
cd /home/freddie/Projects/Gitpak/Repos
sudo rm -rf hellwal
