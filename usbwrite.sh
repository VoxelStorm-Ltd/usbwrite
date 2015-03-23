#!/bin/bash
# Clone an existing directory and contents to a number of USB drives, with file contents specified by lists

# set time and date with
# IFS=$'\n' bash -c 'touch -c -t 201503251337.00 $(find "./tree/")'

diskblacklistfile="disk_blacklist.txt"

searchdevice="$1"
sourcetree="$2"
mountpoint="./mnt"
mkdir -p "$mountpoint"

if [ "$searchdevice" = "" ] || [ "$sourcetree" = "" ]; then
  echo "Usage: $0 targetdevice sourcetree"
  echo "  i.e. $0 /dev/sdb ./tree/"
  exit 1
fi

count=0

while true; do
  ((count++))
  #dmesg | fgrep sd | fgrep 'Attached SCSI removable disk'
  echo "Waiting for USB drive $count..."
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
  rsync -a --info=progress2 "$tree" "$mountpoint"

  echo "Updating templated files..."
  echo "$key_game" > "$mountpoint/Game Download Key.txt"
  echo "$key_ost" > "$mountpoint/Soundtrack Download Key.txt"

  echo "Applying label..."
  # TODO

  echo "Setting modified times to $(stat "$sourcetree" | grep ^Modify | cut -d ' ' -f 2-3)..."
  OLDIFS="$IFS"
  IFS=$'\n'
  for file in $(find "$mountpoint"); do
    #echo "$file"; touch -c -t 201503211337.00 "$file"
    echo "$file"; touch -c -r "$sourcetree" "$file"
  done
  IFS="$OLDIFS"

  echo "Synchronosing buffers and unmounting..."
  sync
  umount "$device"

  echo "Ready to remove USB device $count."
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
