#!/bin/bash

set -e

echo "Installing nfs-utils..."
yum install -y nfs-utils
echo "Starting firewalld..."
systemctl enable firewalld --now
echo "Opening ports ..."
firewall-cmd --add-service="nfs3" --add-service="rpc-bind" --add-service="mountd" --permanent
firewall-cmd --reload
echo "Starting nfs server..."
systemctl enable nfs --now
echo "Creating share directory..."
mkdir -p /srv/share/upload
chown -R nfsnobody:nfsnobody /srv/share
chmod 0777 /srv/share/upload
touch /srv/share/upload/test_file
echo "Editing exports file..."
echo "/srv/share 192.168.50.11/32(rw,sync,root_squash)" >> /etc/exports
exportfs -r


