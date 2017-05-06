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
#     - moved listing of user installed scripts to variable for better checking
#       if scripts exist or not
#     - remove all debug files execpt the actuall docked/undocked run, execpt
#       when the word 'keep' is in the debug flag
#     - moved debug flag into debugFlag variable, easier updating as it's now
#       checked in several places
#
#------------------------------------------------------------------------------

   etcDir=/etc/thinkpad-dock
   scriptsDir=${etcDir}/scripts
   debugFlag=${etcDir}/thinkpad-dock.debug

   . ${etcDir}/thinkpad-dock.conf

   debugLog=/tmp/$( basename $0 ).debug.log.$$
   [[ -f ${debugFlag} ]] && exec >${debugLog} 2>&1 && set -x

   loggedInUsers="$( who | awk '/tty[7-9].*\(:[0-9]\)/{ print $1 }' )"

   if [[ ${devicePath} == login ]] || [[ ${devicePath} =~ lightdm ]]
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

   if ! ${pass}
   then
      remove_debug_file
      return 1
   fi

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

   if ! ${pass}
   then
      remove_debug_file
      return 2
   fi

   #--------------------------------------
   # We've gotten this far, it's supported. Lets log that
   deviceName=$( lsusb -d ${vendorId}:${productId} \
      | awk '{ for (i=7; i<=NF; i++) printf("%s ",$i) }END{ print"" }' )
   echo "INFO: Found Supported Thinkpad Dock - " \
      "${vendorId}:${productId} ${deviceName}"

   return 0
}

#--------------------------------------

remove_debug_file()
{
#
# Disable debug for this run and remove all logs but docked
# If keep is inside the debug flag then keep all logs
#
   if [[ -f ${debugFlag} ]] && ! grep -q keep ${debugFlag}
   then
      set +x
      rm -f ${debugLog}
   fi

   return 0
}
#--------------------------------------

run_user_scripts()
{
#
# Execute scripts in S{scriptDir}
#

   userScripts="$( ls ${scriptsDir}/*.sh )"

   if [[ -z ${userScripts} ]]
   then
      echo "INFO: no user scripts found"
      return 0
   fi

   for script in ${userScripts}
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

   return 0
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
      if [[ ${deviceAction} == undocked ]]
      then
         echo "INFO: undocked function currently not supported"
         remove_debug_file
         exit 0
      fi ;;
   login|lightdm*)
      run_user_scripts
      ;;
#   *)
#      if is_docked
#      then
#         run_user_scripts ; exit $?
#      fi ;;
esac

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
