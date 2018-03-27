#!/bin/bash

# Scan for all devices other than sda (OS disk) and sdb (temp disk)
devices=$(ls -1 /dev/sd* | egrep -v "sd[a|b]")
numDevices=0
deviceList=""
for device in $devices
do
  numDevices=$(($numDevices + 1))
  if [ -z "$deviceList" ];
  then
    deviceList=$device
  else
    deviceList="$deviceList $device"
  fi
  echo "Device $numDevices found: $device"
done
#echo "Device list: #$deviceList#"

# Create RAID0, format it and mount it on /data
mdadm --create /dev/md0 --level=0 --raid-devices=$numDevices $deviceList
mkfs.ext4 -F /dev/md0
mkdir -p /data
mount /dev/md0 /data

# Make the RAID changes permanent
# The following does not work on Ubuntu
#mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
uuid=$(sudo mdadm -b --detail --scan | cut -d ' ' -f 5)
echo "ARRAY /dev/md0 metadata=1.2 $uuid" | sudo tee -a /etc/mdadm/mdadm.conf
update-initramfs -u -k all

# Make the mount permanent
echo '/dev/md0 /data ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab