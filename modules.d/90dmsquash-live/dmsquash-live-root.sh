#!/bin/sh
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
HOST="$(cat /proc/sys/kernel/hostname )"

modprobe squashfs
modprobe overlay

mkdir -m 0755 -p /run/{upper,work,sysroot}

livedev="$1"
udevadm settle
mount -n -t squashfs -o ro $livedev /run/sysroot
mount -t overlay -o lowerdir=/run/sysroot,upperdir=/run/upper,workdir=/run/work overlay "${NEWROOT}"
ln -nfs "${NEWROOT}" /dev/root

#Pull the per host configurations
curl --connect-timeout 600 -4 -s "http://${SRV_IP}:70/hosts/$HOST.tgz" | tar -C "${NEWROOT}" -xvzf -
[ $? -ne 0 ] && echo "unable to pull config"

need_shutdown

exit 0
