#!/bin/bash

# Scan for all devices other than sda (OS disk)
# The temp disk can be sdb
devices=$(ls -1 /dev/sd* | egrep -v "sda")
numDevices=0
deviceList=""
for device in $devices
do
  # Check whether the device is mounted (could be the temp disk)
  mounted=$(mount | grep $device)
  if [ -z "$mounted" ];
  then
    numDevices=$(($numDevices + 1))
    if [ -z "$deviceList" ];
    then
      deviceList=$device
    else
      deviceList="$deviceList $device"
    fi
    echo "Device $numDevices found: $device"
  else
    echo "$device seems to be mounted, must be the temp disk"
  fi
done
#echo "Device list: #$deviceList#"

# Create RAID0, format it and mount it on /data
mdadm --create /dev/md0 --level=0 --raid-devices=$numDevices $deviceList
mkfs.ext4 -F /dev/md0
mkdir -p /data
mount /dev/md0 /data

# Make the RAID changes permanent
# Create /etc/mdadm if it did not exist
mdadmDirExists=$(ls -ald /etc/mdadm 2>/dev/null)
if [ -z "$mdadmDirExists" ];
then
  mkdir /etc/mdadm
fi
# The following does not work on Ubuntu
#mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
# Therefore we do it the manual (and more fragile) way
uuid=$(sudo mdadm -b --detail --scan | cut -d ' ' -f 5)
echo "ARRAY /dev/md0 metadata=1.2 $uuid" | sudo tee -a /etc/mdadm/mdadm.conf
initramfsExists=$(which update-initramfs 2>/dev/null)
if [ -z "$initramfsExists" ];
then
  echo "update-initramfs not found"
else
  update-initramfs -u -k all
fi

# Make the mount permanent
echo '/dev/md0 /data ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab