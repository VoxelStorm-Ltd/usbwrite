#!/bin/bash

image_dir=$1
template_dir=$2
label=$3
shift 3
if [ -z "$1" ]; then
  echo "Usage: $0 <image dir> <template dir> <volume label> <device list>"
  echo "   eg: $0 image template SPHEREFACE /dev/sd{d..j}"
  exit 1
fi

echo "Writing $label to devices $@"

while true; do
  for device in $@; do
    ./usbwrite.sh 1 "$device" "$image_dir" "$template_dir" "$label" | sed 's/^/'"$(basename "$device")"': /' &
  done
  wait

  echo "All devices ready.  Press any key to begin again or ctrl-c to end."
  read
done
