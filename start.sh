#!/bin/bash
set -e

source app-urls.env

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
    echo 'Defaults    timestamp_timeout=30' >> /etc/sudoers
}

# remove snap packages and snap service all together
remove_snap() {
    echo "Removing all Snap packages..."
    # Get a list of all installed snap packages
    local packages
    packages=$(snap list | awk 'NR > 1 {print $1}')

    # Loop through the list and remove each package
    while snap list | awk 'NR > 1 {print $1}' | grep .; do
        for snap_package in $packages; do
            echo "Removing $snap_package..."
            snap remove "$snap_package" || true
            sleep 2  # Adding a short delay to ensure the package is removed
        done
    echo "Waiting for Snap packages to be fully removed..."
    sleep 5
    done

    # remove snapd service
    echo "Stopping and disabling snapd service..."
    systemctl stop snapd || true
    systemctl disable snapd || true
    systemctl mask snapd || true
    echo "Removing Snapd service..."
    apt-get purge -y snapd || true

    # create preference file to prevent snap to reinstalling itself
    echo "Creating preference file to prevent Snap from being reinstalled..."
    echo "Package: snapd" | tee /etc/apt/preferences.d/nosnap.pref > /dev/null
    echo "Pin: release a=*" | tee -a /etc/apt/preferences.d/nosnap.pref > /dev/null
    echo "Pin-Priority: -10" | tee -a /etc/apt/preferences.d/nosnap.pref > /dev/null
}

# install firefox
install_firefox() {
    echo "Adding Mozilla's APT repository and installing Firefox..."
    install -d -m 0755 /etc/apt/keyrings
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null
    echo "Package: *" | tee /etc/apt/preferences.d/mozilla > /dev/null
    echo "Pin: origin packages.mozilla.org" | tee -a /etc/apt/preferences.d/mozilla > /dev/null
    echo "Pin-Priority: 1000" | tee -a /etc/apt/preferences.d/mozilla > /dev/null
    apt update && apt install -y firefox
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
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker $LOCAL_USERNAME

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

# install telegram
install_telegram() {
    wget ${TELEGRAM_URL}
    tar xvpf tsetup*.tar.xz
    mv Telegram/Telegram /usr/bin/
    rm -rf Telegram tsetup*.tar.xz
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
    adduser ${LOCAL_USERNAME} libvirt
    adduser ${LOCAL_USERNAME} kvm
}

install_packages_for_sway() {
    # install neccessary packages
    apt update
    apt install -y $(cat packages.txt)
    apt autoremove -y
}

# setup steps for sway
setup_sway() {
    mkdir -p /home/${LOCAL_USERNAME}/.ssh
    mkdir -p /home/${LOCAL_USERNAME}/scm/github.com
    mkdir -p /home/${LOCAL_USERNAME}/tmp
    mkdir -p /home/${LOCAL_USERNAME}/downloads/isos
    mkdir -p /home/${LOCAL_USERNAME}/downloads/telegram
    mkdir -p /home/${LOCAL_USERNAME}/pictures/screenshots
    mkdir -p /home/${LOCAL_USERNAME}/sync

    cp -R .config /home/${LOCAL_USERNAME}/
    chown -R ${LOCAL_USERNAME}:${LOCAL_USERNAME} /home/${LOCAL_USERNAME}/
}

alsa_audio() {
    touch /etc/modprobe.d/alsa-base.conf
    echo "options snd-hda-intel power_save=0 power_save_controller=N" > /etc/modprobe.d/alsa-base.conf
}

remove_unwanted_packages() {
    apt remove -y foot
    apt autoremove -y
}

# install options
case "$1" in
    initialSetup)
        echo "starting initial setup..."
        echo -n "Enter username to add groups(docker,kvm,libvirt): "
        read LOCAL_USERNAME
        remove_snap
        relink_sh
        update_upgrade
        setup_sudoers
        install_packages_for_sway
        install_firefox
        setup_vscode
        setup_terraform
        setup_docker
        install_k9s
        install_telegram
        install_kubectl
        setup_golang
        setup_virt
        install_bssh
        remove_unwanted_packages
        setup_sway
        alsa_audio
        systemctl reboot
        ;;
    removeSnap)
        echo "removing snap..."
        remove_snap
        systemctl reboot
        ;;
    *)
        echo "Available commands: [initialSetup], [removeSnap]"
        ;;
esac
