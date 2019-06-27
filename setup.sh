#!/bin/bash

installOZS() {
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
}

installMonitor() {
    version=$(curl -s https://api.github.com/repos/paradoxxxzero/gnome-shell-system-MONITOR-applet/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    wget "https://codeload.github.com/paradoxxxzero/gnome-shell-system-MONITOR-applet/zip/$version"
    unzip v38 -d .
    cd gnome-shell-system-MONITOR-applet-*
    make install
    rm -r gnome-shell-system-MONITOR-applet-*
}

installNBFC() {
    cd
    git clone https://github.com/hirschmann/nbfc.git
    cd nbfc
    wget https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
    sudo mono nuget.exe restore

    echo '#!/bin/bash
# build solution
xbuild /t:Clean /p:Configuration=ReleaseLinux NoteBookFanControl.sln
xbuild /t:Build /p:Configuration=ReleaseLinux NoteBookFanControl.sln
popd' >build.sh

    sudo ./build.sh
    cd Linux
    sudo ./nbfcservice.sh start
    sudo cp -r bin/Release/ /opt/nbfc/
    sudo cp nbfc.service /opt/nbfc/
    sudo cp nbfc-sleep.service /opt/nbfc/
    sudo cp nbfc.service /etc/systemd/system/
    sudo cp nbfc-sleep.service /etc/systemd/system/
    sudo systemctl enable nbfc --now
    sudo cp /media/${USER}/SSD/Mibook13.xml /opt/nbfc/Configs
    sudo mono /opt/nbfc/nbfc.exe config --apply Mibook13

    echo '#!/bin/bash
sudo systemctl start nbfc
sudo mono /opt/nbfc/nbfc.exe config --apply Mibook13
sudo mono /opt/nbfc/nbfc.exe status -a' >nbfc.sh

    sudo chmod +x nbfc.sh
    sudo mv nbfc.sh /etc/init.d/

    sudo update-rc.d nbfc.sh defaults

    sudo rm nuget.exe

    cd
    rm -r nbfc
}

installUndervolt() {
    pip3 install undervolt
    sudo undervolt --core -100 --cache -100 --gpu -60

    echo '[Unit]
Description=undervolt

[Service]
Type=oneshot
# If you have installed undervolt globally (via sudo pip install):
ExecStart=undervolt -v --core -100 --cache -100 --gpu -60' >undervolt.service

    sudo mv undervolt.service /etc/systemd/system/undervolt.service

    echo '[Unit]
Description=Apply undervolt settings

[Timer]
Unit=undervolt.service
# Wait 2 minutes after boot before first applying
OnBootSec=2min
# Run every 30 seconds
OnUnitActiveSec=30

[Install]
WantedBy=multi-user.target' >undervolt.timer

    sudo mv undervolt.timer /etc/systemd/system/undervolt.timer

    sudo systemctl start undervolt
    sudo systemctl enable undervolt.timer
    sudo systemctl start undervolt.timer

    cd
}

swap() {
    SIZE=$(whiptail --inputbox "Type your RAM size in GB" 8 78 8 --title "Size for swapfile" 3>&1 1>&2 2>&3)
    SIZE=$(($SIZE * 1024 * 1024))
    sudo swapoff /swapfile
    sudo dd if=/dev/zero of=/swapfile bs=1024 count=$SIZE
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
}

installLibinput() {
    sudo gpasswd -a $USER input
    sudo apt install xdotool wmctrl libinput-tools -y
    git clone https://github.com/bulletmark/libinput-gestures.git
    cd libinput-gestures
    sudo make install
    PATH=$(whiptail --inputbox "If you have a config file, type the path, if not leave it blank" 8 78 /path/to/your/libinput-gestures.conf --title "Load config" 3>&1 1>&2 2>&3)
    if test ! -z "$PATH"; then
        cp $PATH ~/.config/libinput-gestures.conf
    fi
    libinput-gestures-setup autostart
    libinput-gestures-setup start
    newgrp input

}

install="gnupg ca-certificates curl unzip"
OZS="false"
MONITOR="false"
INBFC="false"
IUNDERVOLT="false"
ISWAPFILE="false"
ILIBINPUT="false"

whiptail --title "Installation" --checklist --separate-output "Selecciona" 20 78 15 \
    "Chrome" "Install Google Chrome" off \
    "Exfat" "Exfat fuse and utils" off \
    "Git" "" off \
    "OhMyZsh" "Oh my zsh with some plugins" off \
    "Extensions" "Chrome gnome extensions and gnome tweaks" off \
    "Monitor" "Gnome shell extension system MONITOR" off \
    "Python3" "" off \
    "Telegram" "" off \
    "Paper" "Paper icon theme" off \
    "NBFC" "Notebook fan control (with Xiaomi air 13 config)" off \
    "Undervolt" "Undervolt service" off \
    "Swapfile" "Enable swapfile" off \
    "Libinput" "Libinput gestures" off \
    "Terminator" "" off 2>results

while read choice; do
    case $choice in
    Chrome) wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo dpkg -i google-chrome-stable_current_amd64.deb
        sudo rm google-chrome-stable_current_amd64.deb
        ;;
    Exfat)
        install="$install exfat-fuse exfat-utils"
        ;;
    Git)
        install="$install git"
        ;;
    OhMyZsh) install="$install zsh zsh-syntax-highlighting fonts-powerline"
        OZS="true"
        echo "$OZS"
        ;;
    Extensions)
        install="$install chrome-gnome-shell gnome-tweaks"
        ;;
    Monitor)
        install="$install gir1.2-gtop-2.0 gir1.2-networkmanager-1.0 gir1.2-clutter-1.0"
        MONITOR="true"
        ;;
    Python3)
        install="$install python3 python3-pip"
        ;;
    Telegram)
        install="$install telegram-desktop"
        ;;
    Paper)
        sudo add-apt-repository -u ppa:snwh/ppa
        install="$install paper-icon-theme"
        ;;
    NBFC)
        sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
        echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
        sudo apt update
        install="$install mono-devel mono-complete"
        INBFC="true"
        ;;
    Undervolt)
        IUNDERVOLT="true"
        ;;
    Swapfile)
        ISWAPFILE="true"
        ;;
    Libinput)
        ILIBINPUT="true"
        ;;
    Terminator)
        install="$install terminator"
        ;;
    esac
done < results

sudo apt install $install

if [ "$MONITOR" == "true" ]; then
    installMonitor
fi

if [ "$INBFC" == "true" ]; then
    installNBFC
fi

if [ "$IUNDERVOLT" == "true" ]; then
    installUndervolt
fi

if [ "$ISWAPFILE" == "true" ]; then
    swap
fi
echo "$ILIBINPUT"
if [ "$ILIBINPUT" == "true" ]; then
    installLibinput
fi

if [ "$OZS" == "true" ]; then
    installOZS
fi

echo "Setup finished"
