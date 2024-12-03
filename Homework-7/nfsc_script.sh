#!/bin/bash

set -e

echo "Installing nfs-utils..."
yum install -y nfs-utils
echo "Starting firewall..."
systemctl enable firewalld --now
echo "Editing fstab file..."
echo "192.168.50.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab
echo "Reload systemd..."
systemctl daemon-reload
systemctl restart remote-fs.target

