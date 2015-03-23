#!/bin/bash
# Clone an existing directory and contents to a number of USB drives, with file contents specified by lists

# set time and date with
# IFS=$'\n' bash -c 'touch -c -t 201503251337.00 $(find "./tree/")'

diskblacklistfile="disk_blacklist.txt"

maxcount="$1"
searchdevice="$2"
sourcedir="$3"
templatedir="$4"
label="$5"
count="$6"
mountpoint="./mnt"
mkdir -p "$mountpoint"

if [ "$maxcount" = "" ] || \
   [ "$searchdevice" = "" ] || \
   [ "$sourcedir" = "" ] || \
   [ "$templatedir" = "" ]; then
  echo "Usage: $0 count targetdevice sourcedir templatedir [volumelabel] [startcount]"
  echo "  i.e. $0 21 /dev/sdb ./source ./templates AdvertCity 1"
  exit 1
fi

echo "Verifying templated files in $templatedir..."
pushd "$templatedir" >/dev/null
IFS=$'\n'
templatefilelist=$(find | grep ".template$")
templatelistcount=$(echo "$templatefilelist" | wc -l)
echo "  $templatelistcount templated files found."
popd >/dev/null
templateentrylist=$(
  for templatefile in $templatefilelist; do
    grep -o -P "\[\[.*?\]\]" "$templatedir/$templatefile"
  done | sort | uniq | sed 's/^\[\[//;s/\]\]$//'
)
templateentrycount=$(echo "$templateentrylist" | wc -l)
echo "  $templateentrycount unique template sources."
for templateentry in $templateentrylist; do
  templateentryfile="$templatedir/$templateentry"
  echo -n "Checking $templateentryfile: "
  if ! [ -f "$templateentryfile" ]; then
    referencedlocations=$(
      for templatefile in $templatefilelist; do
        fgrep -Hn "[[$templateentry]]" "$templatedir/$templatefile"
      done
    )
    echo
    echo "ERROR: could not find template source file $templateentryfile"
    echo "  referenced in:"
    echo "$referencedlocations" | sed 's/^/    /;s/:/\n      line /;s/:/:\n        /'
    exit 1
  fi
  templateentryfilelinecount=$(cat "$templateentryfile" | wc -l)
  echo "$templateentryfilelinecount entries"
  if [ "$templateentryfilelinecount" -lt "$maxcount" ]; then
    echo "ERROR: $templateentryfile has fewer entries than the number of drives expected to write!"
    exit 1
  fi
done

if [ "$count" = "" ]; then
  count=1
fi

while [ "$count" -lt "$maxcount" ]; do
  #dmesg | fgrep sd | fgrep 'Attached SCSI removable disk'
  echo "Waiting for USB drive $count..."
  deviceline=""
  #tail -f templog -n0 | 'fgrep' --line-buffered sd | 'fgrep' --line-buffered "Attached SCSI removable disk" | read -r -s -n 30 templine
  while true; do
    # loop until we get a device or told to cancel
    #deviceline=$(mount | fgrep /dev/sd | fgrep vfat)
    deviceline=$(fdisk -l "$searchdevice" | grep "^/dev/" | fgrep "FAT32" 2>/dev/null)
    if [ "$deviceline" != "" ]; then
      break
    fi
    #echo -n $'\a'
    sleep 1
  done
  device=${deviceline%% *}
  echo "New FAT32 device found: $device"
  dosfsck -a "$device"
  echo "Device size $(echo "$deviceline" | tr -s ' ' | cut -d ' ' -f 5) label \"$(dosfslabel "$device")\""
  if grep -q "^$device$" "$diskblacklistfile"; then
    echo "$device matches a blacklisted device in $diskblacklistfile - aborting!"
    break
  fi
  mounted=$(mount | fgrep "$device")
  if [ "$mounted" != "" ]; then
    echo "Device is mounted at $(echo "$mounted" | cut -d ' ' -f 3), unmounting..."
    umount "$device" || (echo "ERROR: unable to unmount $device! Aborting for safety."; exit 1)
  fi
  echo "Mounting device at $mountpoint..."
  mount "$device" "$mountpoint"

  echo "Copying data..."
  #rsync -rt -c --info=progress2 --delete "$sourcedir" "$mountpoint"
  # faster but potentially inaccurate:
  rsync -rt --size-only --info=progress2 --delete "$sourcedir" "$mountpoint"

  echo "Updating templated files..."
  for templatefile in $templatefilelist; do
    # we want to minimise writes to the destination, so modify the temp file and then write it when done
    destinationfile="$mountpoint/$(echo "$templatefile" | sed 's/.template$//')"
    tempfile=$(mktemp)
    cp "$templatedir/$templatefile" "$tempfile"
    for templateentry in $templateentrylist; do
      # escapes for replace from http://stackoverflow.com/a/2705678/1678468
      templateentryline=$(tail -n +$count "$templatedir/$templateentry" | head -1 | sed -e 's/[\/&]/\\&/g')
      templateentryescaped=$(echo "$templateentry" | sed -e 's/[]\/$*.^|[]/\\&/g')
      sed -i -e 's/\[\['"$templateentryescaped"'\]\]/'"$templateentryline"'/g' "$tempfile"
    done
    echo "DEBUG TEMPLATE BEGIN ############ $templatefile"
    cat "$tempfile"
    echo "DEBUG TEMPLATE END ############## $templatefile"
    mv "$tempfile" "$destinationfile"
  done

  if [ "$label" != "" ]; then
    echo "Applying label \"$label\"..."
    dosfslabel "$device" "$label"
  fi
  echo "Label for $device is $(dosfslabel "$device")"

  echo "Setting modified times to $(stat "$sourcedir" | grep ^Modify | cut -d ' ' -f 2-3)..."
  OLDIFS="$IFS"
  IFS=$'\n'
  for file in $(find "$mountpoint"); do
    #echo "$file"
    #touch -c -t 201503211337.00 "$file"
    touch -c -r "$sourcedir" "$file"
  done
  IFS="$OLDIFS"

  echo "Synchronosing buffers and unmounting..."
  sync
  umount "$device"

  echo "Ready to remove USB device $count."
  while true; do
    # wait for device to be removed
    deviceline=$(fdisk -l "$searchdevice" | grep "^/dev/" | fgrep "FAT32" 2>/dev/null)
    if [ "$deviceline" = "" ]; then
      break
    fi
    echo -n $'\a'
    sleep 1
  done
  ((count++))
done
