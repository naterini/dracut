#!/bin/sh

# run lvm scan if udev has settled

. /lib/dracut-lib.sh

VGS=$(getargs rd_LVM_VG=)
LVS=$(getargs rd_LVM_LV=)

[ -d /etc/lvm ] || mkdir -p /etc/lvm
# build a list of devices to scan
lvmdevs=$(
    for f in /tmp/.lvm_scan-*; do
	[ -e "$f" ] || continue
	echo -n "${f##/tmp/.lvm_scan-} "
    done
)

if [ ! -e /etc/lvm/lvm.conf ]; then 
    {
	echo 'devices {';
	echo -n '    filter = [ '
	for dev in $lvmdevs; do
	    printf '"a|^/dev/%s$|", ' $dev;
	done;
	echo '"r/.*/" ]';
	echo '}';	  
	# establish read-only locking
	echo 'global {';
	echo '    locking_type = 4';
	echo '}';
    } > /etc/lvm/lvm.conf
    lvmwritten=1
fi

check_lvm_ver() {
    maj=$1; shift;
    min=$1; shift;
    ver=$1; shift;
    # --poll is supported since 2.2.57
    [ $1 -lt $maj ] && return 1
    [ $1 -gt $maj ] && return 0
    [ $2 -lt $min ] && return 1
    [ $2 -gt $min ] && return 0
    [ $3 -ge $ver ] && return 0
    return 1
}

lvm version 2>/dev/null | ( \
    IFS=. read maj min sub; 
    maj=${maj##*:}; 
    sub=${sub%% *}; sub=${sub%%\(*}; 
    ) 2>/dev/null 

nopoll=$(
    # hopefully this output format will never change, e.g.:
    #   LVM version:     2.02.53(1) (2009-09-25)
        check_lvm_ver 2 2 57 $maj $min $sub && \
            echo " --poll n ";
)

sysinit=$(
    # hopefully this output format will never change, e.g.:
    #   LVM version:     2.02.53(1) (2009-09-25)
        check_lvm_ver 2 2 65 $maj $min $sub && \
            echo " --sysinit ";
)

export LVM_SUPPRESS_LOCKING_FAILURE_MESSAGES=1

if [ -n "$LVS" ] ; then
    info "Scanning devices $lvmdevs for LVM logical volumes $LVS"
    lvm lvscan --ignorelockingfailure 2>&1 | vinfo
    if [ -z "$sysinit" ]; then
        lvm lvchange -ay --ignorelockingfailure $nopoll --ignoremonitoring $LVS 2>&1 | vinfo
    else
        lvm lvchange -ay $sysinit $LVS 2>&1 | vinfo
    fi
fi

if [ -z "$LVS" -o -n "$VGS" ]; then
    info "Scanning devices $lvmdevs for LVM volume groups $VGS"
    lvm vgscan --ignorelockingfailure 2>&1 | vinfo
    if [ -z "$sysinit" ]; then
        lvm vgchange -ay --ignorelockingfailure $nopoll --ignoremonitoring $VGS 2>&1 | vinfo
    else
        lvm vgchange -ay $sysinit $VGS 2>&1 | vinfo
    fi
fi

if [ "$lvmwritten" ]; then
    rm -f /etc/lvm/lvm.conf
    ln -s /sbin/lvm-cleanup /pre-pivot/30-lvm-cleanup.sh 2>/dev/null
    ln -s /sbin/lvm-cleanup /pre-pivot/31-lvm-cleanup.sh 2>/dev/null
fi
unset lvmwritten
