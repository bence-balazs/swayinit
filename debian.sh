#!/bin/bash
set -euxo pipefail

# app urls
TERRAFORM_URL="https://releases.hashicorp.com/terraform/1.13.3/terraform_1.13.3_linux_amd64.zip"
GOLANG_URL="https://go.dev/dl/go1.25.1.linux-amd64.tar.gz"
K9S_URL="https://github.com/derailed/k9s/releases/download/v0.50.12/k9s_linux_amd64.deb"

# relink sh from dash to bash
relink_sh() {
    rm -rf /usr/bin/sh
    ln -s /usr/bin/bash /usr/bin/sh
}

# update system & upgrade
update_upgrade() {
    apt update && apt upgrade -y
}

# set sudo timeout
setup_sudoers() {
    # set sudo timeout
    echo 'Defaults    timestamp_timeout=30' >> /etc/sudoers
    # add user to sudoers
    echo "${LOCAL_USERNAME} ALL=(ALL:ALL) ALL" >> /etc/sudoers
}

# setup vscode repository and install it
setup_vscode() {
    apt-get install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    apt install apt-transport-https
    apt update
    apt install code # or code-insiders
}

# setup terraform
setup_terraform() {
    wget ${TERRAFORM_URL}
    unzip terraform*.zip terraform
    mv terraform /usr/bin/
    rm -rf terraform*.zip
}

# setup docker repository and install it
setup_docker() {
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker $LOCAL_USERNAME

    # set bash-completition for docker
    mkdir -p /etc/bash_completion.d
    docker completion bash > /etc/bash_completion.d/docker
}

# setup golang
setup_golang() {
    echo '# GOLANG PATH' >> /etc/profile
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile

    wget ${GOLANG_URL}
    rm -rf /usr/local/go && tar -C /usr/local -xzf go*.tar.gz
    rm -rf go*.tar.gz
}

# install k9s
install_k9s() {
    wget ${K9S_URL}
    apt install -y ./k9s*.deb
    rm -rf k9s*.deb
}

# download bssh
install_bssh() {
    wget https://github.com/bence-balazs/bssh/releases/download/1.0/bssh_glibc
    mv bssh_glibc /usr/bin/bssh
    chmod +x /usr/bin/bssh
}

install_kubectl() {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -rf kubectl
}

# setup virt-manager
setup_virt() {
    systemctl enable libvirtd
    sudo adduser ${LOCAL_USERNAME} libvirt
    sudo adduser ${LOCAL_USERNAME} kvm
}

# Setup thinkfan
setup_thinkfan() {
    sudo tee /etc/thinkfan.conf > /dev/null <<'EOF'
sensors:
- tpacpi: /proc/acpi/ibm/thermal
  indices: [0]

fans:
- tpacpi: /proc/acpi/ibm/fan

levels:
- [0, 0,  5]
- [1, 3, 65]
- [5, 60, 66]
- [6, 63, 68]
- [7, 65, 74]
- [127, 70, 32767]
EOF
    # echo "options thinkpad_acpi fan_control=1" | sudo tee /etc/modprobe.d/thinkfan.conf
    # sudo modprobe -r thinkpad_acpi
    # sudo modprobe thinkpad_acpi
    sudo systemctl enable thinkfan
}

remove_bloat() {
    # Update package list
    sudo apt update

    # Remove common bloatware apps
    REMOVE_PACKAGES=(
    libreoffice*
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-clocks
    gnome-characters
    gnome-dictionary
    gnome-font-viewer
    gnome-logs
    gnome-software
    gnome-sound-recorder
    gnome-terminal
    gnome-tour
    cheese
    evolution
    rhythmbox
    simple-scan
    transmission-gtk
    totem
    yelp
    thunderbird
    shotwell
    aisleriot
    five-or-more
    four-in-a-row
    hitori
    iagno
    lightsoff
    quadrapassel
    swell-foop
    tali
    )

    # Remove them
    sudo apt purge -y "${REMOVE_PACKAGES[@]}"

    # Autoremove leftovers
    sudo apt autoremove -y --purge

    # Clean cache
    sudo apt clean
}

install_packages() {
    # Update package index
    sudo apt update

    # Define the list of packages you want
    PACKAGES=(
    fastfetch
    xfce4-terminal
    unzip
    p7zip-full
    vim
    sudo
    git
    git-lfs
    htop
    bash-completion
    bat
    fd-find
    ffmpeg
    fzf
    lm-sensors
    make
    nvtop
    ripgrep
    sqlite3
    ansible
    pwgen
    tmux
    tree
    unzip
    fonts-dejavu
    fonts-dejavu-core
    fonts-dejavu-extra
    fonts-dejavu-web
    fonts-firacode
    fonts-font-awesome
    fonts-noto-mono
    fonts-cantarell
    fonts-cascadia-code
    gnupg
    ca-certificates
    virt-manager
    qemu-system
    thinkfan
    gnome-tweaks
    gnome-shell-extension-manager
    )

    # Install them
    sudo apt install -y "${PACKAGES[@]}"

    # Clean up
    sudo apt autoremove -y
    sudo apt clean
}

echo -n "Enter username to add groups(docker,kvm,libvirt): "
read LOCAL_USERNAME
relink_sh
update_upgrade
remove_bloat
install_packages
setup_vscode
setup_terraform
setup_docker
install_k9s
install_kubectl
setup_golang
setup_virt
install_bssh
setup_thinkfan
setup_sudoers
systemctl reboot
