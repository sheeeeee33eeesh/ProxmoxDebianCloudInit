#!/usr/bin/env bash

VMID=8000
STORAGE=local-lvm

set -x

wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 -O debian-12.qcow2
qemu-img resize debian-12.qcow2 8G
sudo qm stop $VMID
sudo qm destroy $VMID
sudo qm create $VMID --name "debian-12-template-docker" --ostype l26 \
    --memory 2048 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu x86-64-v2-AES --cores 2 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
sudo qm importdisk $VMID  debian-12.qcow2 $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | sudo tee /var/lib/vz/snippets/debian-12-docker.yaml
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent gnupg fish bat fzf fd-find git npm rustc gcc python3-pip python3-venv unzip
    - ln -s /usr/bin/batcat /usr/bin/bat
    - systemctl start qemu-guest-agent
    - wget "https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux-x86_64.tar.gz" -O /opt/nvim.tar.gz
    - tar xzvf /opt/nvim.tar.gz -C /opt
    - ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/bin
    - rm -rf /opt/nvim.tar.gz
    - sudo -u $USER git clone https://github.com/sheeeeee33eeesh/DotFiles /home/$USER/DotFiles 
    - sudo -u $USER mkdir -p /home/$USER/.config
    - sudo -u $USER cp -r /home/$USER/DotFiles/nvim /home/$USER/DotFiles/fish /home/$USER/.config
    - sudo -u $USER fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && cat ~/.config/fish/fish_plugins | while read i ; fisher install $i ; end"
    - sudo -u $USER fish -c "tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time='12-hour format' --rainbow_prompt_separators=Round --powerline_prompt_heads=Round --powerline_prompt_tails=Round --powerline_prompt_style='Two lines, character' --prompt_connection=Solid --powerline_right_prompt_frame=No --prompt_connection_andor_frame_color=Lightest --prompt_spacing=Sparse --icons='Many icons' --transient=No"
    - sudo -u $USER rm -rf /home/$USER/DotFiles
    - chsh -s /usr/bin/fish $USER
    - git clone https://github.com/sheeeeee33eeesh/DotFiles /root/DotFiles 
    - mkdir -p /root/.config
    - cp -r /root/DotFiles/nvim /root/.config
    - rm -rf /root/DotFiles
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772

EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/debian-12-docker.yaml"
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=10.0.0.200/24,gw=10.0.0.1
sudo qm template $VMID
