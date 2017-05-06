#!/bin/bash
#------------------------------------------------------------------------------
#
# Name: thinkpad-dock.sh
#
# Purpose: Iterate through /etc/thinkpad-dock/thinkpad-dock.conf looking for
#     supported Thinkpad Docks. If one is found, run scripts found in
#     /etc/thinkpad-dock/scripts
#
# Scripts: scripts to be run must be in the above mentioned directory and be
#     the following format: XX-i_do_stuff[-root].sh. Scripts are executed in
#     lexical order.
#
#------------------------------------------------------------------------------
#
# LastMod: 20170502 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - created
#
# LastMod: 20170504 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - added initial support for docked/undocked, currently does nothing
#
# LastMod: 20170505 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - added ability to run script as root if root is in the file name
#     - changed all the logger commands to echo to stdout
#
#------------------------------------------------------------------------------

   etcDir=/etc/thinkpad-dock
   scriptsDir=${etcDir}/scripts

   . ${etcDir}/thinkpad-dock.conf

   [[ -f ${etcDir}/thinkpad-dock.sh.debug ]] &&
      exec >/tmp/$( basename $0 ).debug.log.$$ 2>&1 && set -x

   loggedInUsers="$( who | awk '/tty[7-9].*\(:[0-9]\)/{ print $1 }' )"

   devicePath=$( echo ${1} | awk -F"'" '{ print $2 }' )
   deviceAction=${2}

#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

   #--------------------------------------
   # temp code, will remove once supported
   if [[ ${deviceAction} == remove ]]
   then
      echo "INFO: remove function currently not supported"
      exit 0
   fi

   #--------------------------------------
   # Get device info, import variables
   eval $( udevadm info --path=${devicePath} | \
      grep '=' | sed -e "s/E: //" -e "s/=/='/" -e "s/$/\'/" )

   #--------------------------------------
   # Check if VendorID is Supported
   pass=false
   for vendorId in ${supportedVendors}
   do
      if [[ ${ID_VENDOR_ID} == ${vendorId} ]]
      then
         pass=true ; break
      fi
   done
   ${pass} || exit 1

   #--------------------------------------
   # Check if ProductID is Supported
   pass=false
   for productId in ${supportedProducts}
   do
      if echo ${PRODUCT} | grep -q ${productId}
      then
         pass=true ; break
      fi
   done
   ${pass} || exit 2

   #--------------------------------------
   # We've gotten this far, it's supported. Lets log that
   deviceName=$( lsusb -d ${vendorId}:${productId} \
      | awk '{ for (i=7; i<=NF; i++) printf("%s ",$i) }END{ print"" }' )
   echo "INFO: Found Supported Thinkpad Dock - " \
      "${vendorId}:${productId} ${deviceName}"

   #--------------------------------------
   # Execute scripts in S{scriptDir}
   for script in $( ls ${scriptsDir}/*.sh )
   do
      if [[ ! -x ${script} ]]
      then
         echo "DEBUG: script ${script} is not executable"
      else
         if echo ${script} | grep -q root
         then
            echo "INFO: running script ${script} as root"
            ${script}
         else
            for user in ${loggedInUsers}
            do
               echo "INFO: running script ${script} as ${user}"
               if su - ${user} -c "${script}"
               then
                  echo "INFO: ${script} success"
               else
                  echo "FATAL: ${script} failed"
               fi
            done
         fi
      fi
   done

   [[ -z ${script} ]] && echo "INFO: no scripts found"

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
