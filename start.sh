#!/bin/bash
set -e

PACKAGE_FILE=packages.txt

source app-urls.env

# check if packages available in debian repo
check_packages() {
    missing_packages=()  # Array to store missing packages

    while read -r pkg || [ -n "$pkg" ]; do
        # Skip empty lines and comments
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        if apt-cache show "$pkg" > /dev/null 2>&1; then
            echo "✅ $pkg exists in the repo"
        else
            echo "❌ $pkg NOT found in the repo"
            missing_packages+=("$pkg")
        fi
    done < "$PACKAGE_FILE"

    # Exit with error if any package is missing
    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo
        echo "Error: The following package(s) were NOT found in the repo:"
        for pkg in "${missing_packages[@]}"; do
            echo "  - $pkg"
        done
        exit 1
    fi
}

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
    apt install -y $(cat ${PACKAGE_FILE})
    apt autoremove -y
}

# setup steps for sway
setup_sway() {
    mkdir -p /home/${LOCAL_USERNAME}/.ssh
    mkdir -p /home/${LOCAL_USERNAME}/scm/github.com
    mkdir -p /home/${LOCAL_USERNAME}/tmp
    mkdir -p /home/${LOCAL_USERNAME}/downloads/isos
    mkdir -p /home/${LOCAL_USERNAME}/pictures/screenshots
    mkdir -p /home/${LOCAL_USERNAME}/sync

    cp -R .config /home/${LOCAL_USERNAME}/
    chown -R ${LOCAL_USERNAME}:${LOCAL_USERNAME} /home/${LOCAL_USERNAME}/
}

alsa_audio() {
    touch /etc/modprobe.d/alsa-base.conf
    echo "options snd-hda-intel power_save=0 power_save_controller=N" > /etc/modprobe.d/alsa-base.conf
}

# Setup thinkfan
setup_thinkfan() {
    CONF_FILE="/etc/thinkfan.conf"

    # Define the new config content
    read -r -d '' CONF_CONTENT <<'EOF'
    sensors:
    - tpacpi: /proc/acpi/ibm/thermal
        indices: [0]

    fans:
    - tpacpi: /proc/acpi/ibm/fan

    levels:
    - [0, 0,  5]
    - [2, 3, 65]
    - [5, 60, 66]
    - [6, 63, 68]
    - [7, 65, 74]
    - [127, 70, 32767]
EOF
    echo "$CONF_CONTENT" | sudo tee "$CONF_FILE" > /dev/null
}

remove_unwanted_packages() {
    apt remove -y foot
    apt autoremove -y
}

# install options
case "$1" in
    initialSetup)
        echo "starting initial setup..."
        check_packages
        echo -n "Enter username to add groups(docker,kvm,libvirt): "
        read LOCAL_USERNAME
        relink_sh
        update_upgrade
        install_packages_for_sway
        install_firefox
        setup_vscode
        setup_terraform
        setup_docker
        install_k9s
        install_kubectl
        setup_golang
        setup_virt
        install_bssh
        remove_unwanted_packages
        setup_sway
        alsa_audio
        setup_thinkfan
        setup_sudoers
        systemctl reboot
        ;;
    checkPackages)
        check_packages
        ;;
    *)
        echo "Available commands: [initialSetup], [checkPackages]"
        ;;
esac
