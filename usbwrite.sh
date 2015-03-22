#!/bin/bash
# Clone an existing directory and contents to a number of USB drives, with file contents specified by lists

# set time and date with
#touch -c -t 201503211337.00 $(find "$sourcetree")

diskblacklistfile="disk_blacklist.txt"

searchdevice="$1"
sourcetree="$2"
mountpoint="./mnt/"
mkdir -p "$mountpoint"

if [ "$searchdevice" = "" ] || [ "$sourcetree" = "" ]; then
  echo "Usage: $0 targetdevice sourcetree"
  echo "  i.e. $0 /dev/sdb ./tree/"
  exit 1
fi

while true; do
  #dmesg | fgrep sd | fgrep 'Attached SCSI removable disk'
  echo "Waiting for new USB drive"
  deviceline=""
  #tail -f templog -n0 | 'fgrep' --line-buffered sd | 'fgrep' --line-buffered "Attached SCSI removable disk" | read -r -s -n 30 templine
  while true; do
    # loop until we get a device or told to cancel
    #deviceline=$(mount | fgrep /dev/sd | fgrep vfat)
    deviceline=$(fdisk -l "$searchdevice" | grep "^/dev/" | fgrep "FAT32")
    if [ "$deviceline" != "" ]; then
      break
    fi
    #echo -n $'\a'
    sleep 1
  done
  device=${deviceline%% *}
  echo "New FAT32 device found: $device size $(echo "$deviceline" | tr -s ' ' | cut -d ' ' -f 5)"
  if grep -q "^$device$" "$diskblacklistfile"; then
    echo "$device matches a blacklisted device in $diskblacklistfile - aborting!"
    break
  fi
  mounted=$(mount | fgrep "$device")
  if [ "$mounted" != "" ]; then
    echo "Device is mounted, unmounting..."
    umount "$device"
  fi
  #mountpoint=$(echo "$deviceline | cut -d ' ' 3)
  echo "Mounting at $mountpoint..."
  mount "$device" "$mountpoint"
  echo "Copying data..."
  rsync -a --info=progress2 "$tree" mnt/
  echo "Applying label..."
  # TODO
  echo "Setting modified times..."
  OLDIFS="$IFS"
  IFS=$'\n'
  for file in $(find "$mountpoint"); do
    #echo "$file"; touch -c -t 201503211337.00 "$file"
    echo "$file"; touch -c -r "$sourcetree" "$file"
  done
  IFS="$OLDIFS"
  echo "Synchronosing buffers..."
  sync
  umount "$device"
  echo "Device ready to remove."
  while true; do
    # wait for device to be removed
    deviceline=$(fdisk -l "$searchdevice" | grep "^/dev/" | fgrep "FAT32")
    if [ "$deviceline" = "" ]; then
      break
    fi
    echo -n $'\a'
    sleep 1
  done
  exit
done
