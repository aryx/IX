\title{usbd}{1}{system}

# NAME
usbd – the USB keyboards and mice found and started

# SYNOPSIS
**usbd**

# DESCRIPTION
*Usbd* walks the USB bus from the root hub, through its hubs, and
for each keyboard and each mouse starts a process that reads its
reports and writes what they mean to the kernel: a keyboard's keys,
as a PC's scancodes, to the keyboard device's `kbin`; a mouse's
moves and buttons to `#m/mousein`. The kernel has the controller and
gives each endpoint as files, `#u`; it knows no device.

*Usbd* returns when it has looked at every port once, the devices
found working. A process stays and looks again four times a second:
a device plugged later is found, one unplugged forgotten.

The boot script runs it.

# FILES
`#u/usb`, `#m/mousein`, the keyboard device's `kbin`

# SEE ALSO
*usbd*(4) and *usb*(3) in Plan 9's manual

# DIAGNOSTICS
No USB, `#u/usb/ep1.0` not there, is said.

# BUGS
Only hubs, keyboards and mice: not Plan 9's drivers of disks, serial
lines, audio or ethernet, nor its file server for drivers that are
other programs.
