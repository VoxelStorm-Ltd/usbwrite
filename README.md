# USBWrite
Utility script for batch writing USB drives with templated content.  Created for VoxelStorm's [sphereFACE game distribution on USB](https://www.kickstarter.com/projects/voxelstorm/sphereface/posts/1821110)

The primary use case is mass-producing almost identical USB drives, with content delivered from a templated directory, but with some personalised variations - for instance, a different product key included on each drive.

### Scripts
- usb_write.sh - Clone an existing directory and contents to a number of USB drives, with file contents specified by lists
- batch_write.sh - helper to dispatch usbwrite.sh on the list of devices

### Basic usage
To write the same content to each disk, just create an `image` directory in which you place all the files as they should appear on your USB drive.  File attributes and modified times will be preserved as far as your chosen filesystem permits.

### Batch writing
Example:
```sh
./batch_write.sh image template MY_USB_LABEL /dev/sd{d..j}
```

### Templated content

To get started, copy the `template_example` directory as a new directory named `template`.

In the top level directory of template, you will see files with one entry per line, with the names `key.txt` and `username.txt`.  These will be filled in, one by one, to any tags with corresponding names in subdirectories in the template.  Tags here would take the format `[[key.txt]]` and `[[username.txt]]`, and those tags will substitute a single line from each file according to the order of writing.

### Disk blacklist

The disk_blacklist.txt file is an optional safety mechanism - you are advised to list all existing system disks in this file.  Any device in this file will never be written to, even if accidentally specified on the commandline.
