#!/bin/bash

#Login credentials for your external storage
KEY=username=borg101,password=Borg3233**

#Are block devices mounted

if [[ ! -d /mnt/block-devices ]]; then
	sudo mkdir -p /mnt/block-devices
	cd /etc/block-fuse
	./block-fuse /dev/mapper /mnt/block-devices
else
	cd /etc/block-fuse
	./block-fuse /dev/mapper /mnt/block-devices
fi

#Is backup directory mounted

if [[ ! -d /mnt/borgbackups ]]; then
    sudo mkdir -p /mnt/borgbackups
	sudo mount -o rw,$KEY,vers=3.0 -t cifs //10.1.1.10/development/borgbackups /mnt/borgbackups
else
	sudo mkdir -p /mnt/borgbackups
    sudo mount -o rw,$KEY,vers=3.0 -t cifs //10.1.1.10/development/borgbackups /mnt/borgbackups
fi

#Check to see if back up folder exist if not create:

if [[ ! -d /mnt/borgbackups/$HOSTNAME ]]; then
	sudo mkdir -p /mnt/borgbackups/$HOSTNAME
fi

#Make array of Running Virtual Machines

name(){
	virsh list | awk '( $1 ~ /^[0-9]+$/ ) { print $2 }'
}

arr=( $( name ) )

for v in ${arr[*]}; do
	if sudo lvdisplay | grep -q $v; then
		#Take snapshots of VMs 
		lvcreate --size 5G -s -n $v-snap /dev/main-vg/$v
		borgrepo=/mnt/borgbackups/$HOSTNAME/$v
		#Check to see if vm has been backed up before and then create backup
		if [[ ! -d $borgrepo ]]; then
	                borg init --encryption=none $borgrepo
	                borg create -C zlib,6 "$borgrepo::$v_{now:%Y-%m-%d}" /mnt/block-devices/main--vg-$v
		else
	                borg create -C zlib,6 "$borgrepo::$v_{now:%Y-%m-%d}" /mnt/block-devices/main--vg-$v

		fi
		#Take a copy of the VM information
		virsh dumpxml $v > /mnt/borgbackups/$HOSTNAME/$v/$(date "+%d.%m.%Y")_$v.xml
		#Take a copy of the LV information
		sudo lvdisplay /dev/main-vg/$v >> /mnt/borgbackups/$HOSTNAME/$v/$(date "+%d.%m.%Y")_$v.lvdisplay
		#Remove snapshot
		lvremove -f /dev/main-vg/$v
	fi
done

###TIDY-UP###

#umount backups and block-devices

sudo umount /mnt/block-devices
sudo umount /mnt/borgbackups

#Finish
echo "VM backup complete"
