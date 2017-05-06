#!/usr/bin/python3
#------------------------------------------------------------------------------
#
# Name: thinkpad-dock.py
#
# Provides: Listening pyudev daemon calls thinkpad-dock.sh on any device insertion
#
# Usage: can be called directly for debug. Started normally by systemd
#
# todo list:
#   - Move most (if not all) processes from thinkpad-dock.sh to this script
#   - Add logging to syslog
#
#------------------------------------------------------------------------------
#
# LastMod: 20170502 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - created
#
# LastMod: 20170504 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - added device removed function (undock)
#
# LastMod: 20170506 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - bugfix, docked/undocked was not a string, or included with subprocess.call
#
#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

import pyudev
import subprocess
import signal
import sys

def signal_handler(signal, frame):
    print('KeyboardInterrupt')
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

context = pyudev.Context()
monitor = pyudev.Monitor.from_netlink(context)
monitor.filter_by(subsystem='usb')

for device in iter(monitor.poll, None):
    if device.action == 'add':
        print('{} connected'.format(device))
        subprocess.call(["/usr/local/bin/thinkpad-dock.sh", str(device), "docked"])

    if device.action == 'remove':
        print('{} disconnected'.format(device))
        subprocess.call(["/usr/local/bin/thinkpad-dock.sh", str(device), "undocked"])

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
