#!/bin/bash

function exit_with_error {
    echo "there are some errors...fail"
    exit 0
}

for i in {b,c,d,e,f,g}; do
    if [ ! -b /dev/sd$i ]; then
        echo "[error]: /dev/sd$i not present, but it is needed for raid configuration"
        err=1
    fi
done

if [ "$err" = "1" ]; then
    exit_with_error
fi

echo "[notice]: clearing super blocks ..."
/usr/sbin/mdadm --zero-superblock --force /dev/sd{b,c,d,e,f,g}

echo "[notice]: creating RAID10 ..."
/usr/sbin/mdadm --create --verbose /dev/md0 -l 10 -n 6 /dev/sd{b,c,d,e,f,g}

echo "[notice]: editing mdadm.conf"
/usr/sbin/mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf

echo "[notice]: updating initramfs ..."
/usr/sbin/update-initramfs -u

echo "[notice]: creating GPT ..."
/usr/sbin/parted -s /dev/md0 mklabel gpt

echo "[notice]: creating partitions ..."
/usr/sbin/parted -a optimal /dev/md0 mkpart primary ext4 3072s 20%
/usr/sbin/parted -a optimal /dev/md0 mkpart primary ext4 20% 40%
/usr/sbin/parted -a optimal /dev/md0 mkpart primary ext4 40% 60%
/usr/sbin/parted -a optimal /dev/md0 mkpart primary ext4 60% 80%
/usr/sbin/parted -a optimal /dev/md0 mkpart primary ext4 80% 100%

echo "[notice]: creating fs on partitions ..."
for i in $(seq 1 5); do 
    /usr/sbin/mkfs.ext4 /dev/md0p$i
done


echo "[notice]: mounting pertitions ..."
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do 
    /usr/bin/mount /dev/md0p$i /raid/part$i 
done

echo "[notice]: add to /etc/fstab"
cp /etc/fstab /etc/fstab.backup
for i in $(seq 1 5); do
    UUID=$(blkid | grep "/dev/md0p$i" | cut -f2 -d'=' | cut -f2 -d'"')
    echo "UUID=$UUID /raid/part$i ext4 defaults 0 0" >> /etc/fstab
done


echo "... done"
