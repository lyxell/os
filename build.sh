#!/usr/bin/env bash

set -exu

ARCH=amd64
SUITE=bookworm
BUILDDIR=build
MIRROR=https://mirror.linux.pizza/debian/
ARTIFACT=filesystem.squashfs
MACHINE=buildroot
# non-free needed because of wifi drivers
COMPONENTS="main non-free"

# Remove files from eventual previous runs
sudo rm -rf $BUILDDIR $ARTIFACT

# Install needed tools on host machine
if ! [ -x "$(command -v debootstrap)" ]; then
    sudo apt install -y debootstrap
fi
if ! [ -x "$(command -v mksquashfs)" ]; then
    sudo apt install -y squashfs-tools
fi

# Bootstrap root file system
if [ ! -f root.tar.gz ]; then
    # TODO: Fix components?
    sudo debootstrap \
        --arch=$ARCH \
        --variant=minbase \
        --components=main,universe \
        --include=systemd,dbus \
        --merged-usr \
        $SUITE \
        $BUILDDIR \
        $MIRROR
    sudo tar -czf root.tar.gz $BUILDDIR
else
    sudo tar -xzf root.tar.gz
fi

echo "deb $MIRROR $SUITE $COMPONENTS" | sudo tee $BUILDDIR/etc/apt/sources.list
echo 'APT::Install-Recommends "0";'   | sudo tee $BUILDDIR/etc/apt/apt.conf
echo "ThinkPad-X230"                  | sudo tee $BUILDDIR/etc/hostname
echo "127.0.0.1 ThinkPad-X230"        | sudo tee $BUILDDIR/etc/hosts

# Download latest package lists
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get update'

# Install essential packages
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    alsa-utils \
    bspwm \
    curl \
    firmware-iwlwifi \
    libasound2 \
    libavformat58 \
    linux-image-amd64 \
    live-boot \
    locales \
    network-manager \
    openssh-client \
    pipewire \
    pipewire-pulse \
    pipewire-media-session \
    sudo \
    tzdata \
    wpasupplicant \
    x11-xserver-utils \
    xdo \
    xdotool \
    xinit \
    xinput \
    xserver-xorg-video-intel \
    xserver-xorg-input-all'

# Install non-essential packages
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bash-completion \
    biber \
    brightnessctl \
    chromium \
    clangd \
    cmake \
    espeak-ng \
    ffmpeg \
    file \
    fonts-firacode \
    fonts-texgyre \
    fzf \
    git \
    less \
    libfontconfig-dev \
    libjs-pdf \
    libxcb-render0-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxml-xpath-perl \
    links \
    make \
    man \
    manpages-dev \
    mpv \
    neomutt \
    ninja-build \
    pandoc \
    playerctl \
    polybar \
    procps \
    psmisc \
    python3 \
    qutebrowser \
    rxvt-unicode \
    silversearcher-ag \
    sxiv \
    texlive-bibtex-extra \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-latex-recommended \
    texlive-luatex \
    texlive-pictures \
    texlive-plain-generic \
    tree \
    unclutter \
    unrar \
    unzip \
    upower \
    wget \
    xclip \
    xdotool \
    xfonts-utils \
    xxd \
    xz-utils \
    youtube-dl \
    zathura \
    zathura-djvu \
    zstd'

# Bluetooth audio
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libspa-0.2-bluetooth \
    bluez-firmware \
    bluez'

# Thesis project
## Report
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fonts-stix \
    python3-pygments'
## Souffle
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    autoconf \
    automake \
    bison \
    build-essential \
    clang \
    doxygen \
    flex \
    g++ \
    gcc \
    git \
    libffi-dev \
    libncurses5-dev \
    libtool \
    libsqlite3-dev \
    make \
    mcpp \
    zlib1g-dev'
## UI
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libsdl2-dev\
    re2c'

# No password to set brightness
echo "user ALL=(ALL) NOPASSWD:/usr/bin/brightnessctl" | sudo tee $BUILDDIR/etc/sudoers.d/brightnessctl
sudo chmod 440 $BUILDDIR/etc/sudoers.d/brightnessctl

# Set timezone
sudo chroot $BUILDDIR sh -c 'rm -f /etc/localtime && \
    ln -s /usr/share/zoneinfo/Europe/Stockholm /etc/localtime'

echo "en_US.UTF-8 UTF-8" | sudo tee $BUILDDIR/etc/locale.gen
sudo chroot $BUILDDIR locale-gen
echo "LANG=en_US.utf8" | sudo tee $BUILDDIR/etc/default/locale

# Create user
sudo chroot $BUILDDIR useradd user \
    --shell /bin/bash \
    --groups sudo \
    --password auYCUPgS0kJzQ

# Create home dir for user
sudo mkdir -p build/home/user/projects
sudo mkdir -p build/home/user/.cache
sudo mkdir -p build/home/user/.local/share
sudo chown -R user:user build/home/user
git clone git@github.com:lyxell/dotfiles.git $BUILDDIR/home/user/projects/dotfiles
sudo chroot --userspec=user:user $BUILDDIR sh -c 'HOME=/home/user && cd ~/projects/dotfiles && ./install.sh'

# Install nodejs
sudo chroot $BUILDDIR sh -c 'curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && apt install -y nodejs'

# Install typescript language server
sudo chroot $BUILDDIR npm install -g typescript-language-server typescript

# Install neovim
wget https://github.com/neovim/neovim/releases/download/v0.7.0/nvim-linux64.deb -O build/home/user/projects/nvim-0.7.0.deb
sudo chroot $BUILDDIR apt install -y /home/user/projects/nvim-0.7.0.deb
git clone --depth 1 https://github.com/wbthomason/packer.nvim $BUILDDIR/home/user/.local/share/nvim/site/pack/packer/start/packer.nvim


# Improve touchpad behavior
echo "options psmouse synaptics_intertouch=1" | sudo tee $BUILDDIR/etc/modprobe.d/psmouse.conf

# Enable bitmap fonts
sudo rm -rf $BUILDDIR/etc/fonts/conf.d/70-no-bitmaps.conf

# Disable suspend on lid close
echo "HandleLidSwitch=ignore" | sudo tee --append $BUILDDIR/etc/systemd/logind.conf

# Install system wide wifi connections
sudo cp -r system-connections/* $BUILDDIR/etc/NetworkManager/system-connections
sudo chmod -R 700 $BUILDDIR/etc/NetworkManager/system-connections

# Xorg config
sudo cp 20-intel-graphics.conf $BUILDDIR/etc/X11/xorg.conf.d/

# Run apt clean
sudo chroot $BUILDDIR apt-get clean

# Make squashed filesystem
sudo mksquashfs $BUILDDIR $ARTIFACT -comp zstd -Xcompression-level 10
