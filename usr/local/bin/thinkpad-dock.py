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
        subprocess.call(["/usr/local/bin/thinkpad-dock.sh", str(device)], docked)
        #print('{} connected'.format(device))

    if device.action == 'remove':
        subprocess.call(["/usr/local/bin/thinkpad-dock.sh", str(device)], undocked)
        #print('{} disconnected'.format(device))

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
