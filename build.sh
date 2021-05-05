#!/usr/bin/env bash

set -exu

ARCH=amd64
SUITE=sid
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
    pulseaudio \
    sudo \
    tzdata \
    x11-xserver-utils \
    xdotool \
    xdo \
    xinit \
    xinput \
    xserver-xorg'

# Install non-essential packages
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bash-completion \
    biber \
    brightnessctl \
    espeak-ng \
    ffmpeg \
    file \
    fzf \
    git \
    less \
    libjs-pdf \
    libxml-xpath-perl \
    links \
    make \
    man \
    mpv \
    neomutt \
    neovim \
    pandoc \
    playerctl \
    procps \
    psmisc \
    python3 \
    manpages-dev \
    qutebrowser \
    rxvt-unicode \
    silversearcher-ag \
    sxiv \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-latex-recommended \
    texlive-luatex \
    texlive-pictures \
    texlive-bibtex-extra \
    fonts-texgyre \
    tree \
    unclutter \
    unrar \
    xclip \
    xdotool \
    xfonts-utils \
    xxd \
    xz-utils \
    youtube-dl \
    wget \
    zathura \
    zathura-djvu'

# Bluetooth audio
sudo chroot $BUILDDIR sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
    pulseaudio-module-bluetooth \
    pavucontrol \
    bluez-firmware \
    bluez'

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

# Create home dir for user and install dotfiles
sudo mkdir -p build/home/user/projects
sudo mkdir -p build/home/user/.cache
sudo mkdir -p build/home/user/.local/share
sudo chown -R user:user build/home/user
git clone git@git.sr.ht:~lyxell/dotfiles build/home/user/projects/dotfiles
sudo chroot --userspec=user:user $BUILDDIR env \
    -i HOME=/home/user bash -c 'cd $HOME/projects/dotfiles && ./install.sh'
git clone git@git.sr.ht:~lyxell/quadratica build/home/user/projects/quadratica
sudo chroot --userspec=user:user $BUILDDIR sh -c 'cd /home/user/projects/quadratica && make && mkdir -p /home/user/.local/share/fonts && cp build/quadratica.otb /home/user/.local/share/fonts'

# Enable bitmap fonts
sudo rm -rf build/etc/fonts/conf.d/70-no-bitmaps.conf

# Disable suspend on lid close
echo "HandleLidSwitch=ignore" | sudo tee --append build/etc/systemd/logind.conf

# Install system wide wifi connections
sudo cp -r system-connections/* $BUILDDIR/etc/NetworkManager/system-connections
sudo chmod -R 700 $BUILDDIR/etc/NetworkManager/system-connections

# Run apt clean
sudo chroot $BUILDDIR apt-get clean

# Make squashed filesystem
sudo mksquashfs $BUILDDIR $ARTIFACT -comp zstd -Xcompression-level 10