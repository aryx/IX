\title{usbd}{1}{system}

# NAME
usbd – the USB keyboards and mice found and started

# SYNOPSIS
**usbd** [ **-v** ]

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

A mouse is read by its own description of its reports (its report
descriptor: where its buttons, its moves and its wheel are), or, if
that is not read, by the boot protocol, whose three bytes may have no
wheel.

The boot script runs it.

**-v**
:    Each step said: what a port answers, what a device is, and how a
     mouse is read.

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
