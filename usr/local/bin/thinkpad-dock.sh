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
# LastMod: 20170506 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - moved tasks into functions, further expanded direct docked/undocked
#       support
#
#------------------------------------------------------------------------------

   etcDir=/etc/thinkpad-dock
   scriptsDir=${etcDir}/scripts

   . ${etcDir}/thinkpad-dock.conf

   [[ -f ${etcDir}/thinkpad-dock.sh.debug ]] &&
      exec >/tmp/$( basename $0 ).debug.log.$$ 2>&1 && set -x

   loggedInUsers="$( who | awk '/tty[7-9].*\(:[0-9]\)/{ print $1 }' )"

   if [[ ${devicePath} == login ]]
   then
      deviceAction=${devicePath}
   else
      devicePath=$( echo ${1} | awk -F"'" '{ print $2 }' )
      deviceAction=${2}
   fi

#------------------------------------------------------------------------------
# --- functions
#------------------------------------------------------------------------------

is_docked()
{
#
# Check if ${devicePath} is a dock
#
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
   ${pass} || return 1

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
   ${pass} || return 2

   #--------------------------------------
   # We've gotten this far, it's supported. Lets log that
   deviceName=$( lsusb -d ${vendorId}:${productId} \
      | awk '{ for (i=7; i<=NF; i++) printf("%s ",$i) }END{ print"" }' )
   echo "INFO: Found Supported Thinkpad Dock - " \
      "${vendorId}:${productId} ${deviceName}"

   return 0
}

#--------------------------------------

run_user_scripts()
{
#
# Execute scripts in S{scriptDir}
#
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
               if su - ${user} -c "${script} ${deviceAction}"
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
}

#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

case ${deviceAction} in
   docked)
      if is_docked
      then
         run_user_scripts ; exit $?
      fi ;;
   undocked)
      #--------------------------------------
      # temp code, will remove once supported
      if [[ ${deviceAction} == undocked ]]
      then
         echo "INFO: undocked function currently not supported"
         exit 0
      fi ;;
   login)
      run_user_scripts
      ;;
esac

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
