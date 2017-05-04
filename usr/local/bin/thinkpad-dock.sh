#!/bin/bash
#------------------------------------------------------------------------------
#
# Name: thinkpad-dock.sh
#
# Purpose: Iterate through /etc/thinkpad-dock/thinkpad-dock.conf looking for
#     supported Thinkpad Docks. If one is found, run scripts found in
#     /etc/thinkpad-dock/scripts
#
# Scripts: scripts to be run must be in the above mentioned directory and be the
#     following format: XX-name.sh. Scripts are executed in lexical order.
#
#------------------------------------------------------------------------------
#
# LastMod: 20170502 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - created
#
#------------------------------------------------------------------------------

   etcDir=/etc/thinkpad-dock
   scriptsDir=${etcDir}/scripts

   . ${etcDir}/thinkpad-dock.conf

   [[ -f ${etcDir}/thinkpad-dock.sh.debug ]] &&
      exec >/tmp/$( basename $0 ).debug.log.$$ 2>&1 && set -x

#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

   devicePath=$( echo ${1} | awk -F"'" '{ print $2 }' )

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
   logger "INFO: Found Supported Thinkpad Dock - " \
      "${vendorId}:${productId} ${deviceName}"

   #--------------------------------------
   # Execute scripts in S{scriptDir}
   for script in $( ls ${scriptsDir}/*.sh )
   do
      if [[ ! -x ${script} ]]
      then
         logger "DEBUG: script ${script} is not executable"
      else
         logger "INFO: running script ${script}"
         ${script} && logger "INFO: ${script} success" || logger "FATAL: ${script} failed"
      fi
   done

   [[ -z ${script} ]] && logger "INFO: no scripts found"

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
