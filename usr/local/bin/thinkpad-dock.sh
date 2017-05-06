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
# LastMod: 20170506 - Michael J. Ford <Michael.Ford@slashetc.us>
#     - should be working now. undocked action still unsupported
#
#------------------------------------------------------------------------------

   etcDir=/etc/thinkpad-dock
   scriptsDir=${etcDir}/scripts
   debugFlag=${etcDir}/thinkpad-dock.debug

   . ${etcDir}/thinkpad-dock.conf

   debugLog=/tmp/$( basename $0 ).debug.log.$$
   [[ -f ${debugFlag} ]] && exec >${debugLog} 2>&1 && set -x

   loggedInUsers="$( who | awk '/tty[7-9].*\(:[0-9]\)/{ print $1 }' )"

   if [[ -z ${1} ]]
   then
      deviceAction=auto-detect
   else
      devicePath=$( echo ${1} | awk -F"'" '{ print $2 }' )
      deviceAction=${2}
   fi

#------------------------------------------------------------------------------
# --- functions
#------------------------------------------------------------------------------

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
         if echo "${loggedInUsers}" | grep -q ${USER} &>/dev/null
         then
            # If the logged in user is calling this,
            # run scripts as that user
            run_script ${script} ${deviceAction}

         elif [[ -z ${USER} ]] && [[ -z ${loggedInUsers} ]]
         then
            # If the USER env var is not defined AND there are no logged in,
            # just run the scripts (cuz we're probably root or lightdm
            run_script ${script} ${deviceAction}

         else
            for user in ${loggedInUsers}
            do
               # otherwise we're being called by the daemon (as root)
               # run scripts as each login user
               run_script ${script} ${deviceAction} ${user}
            done
         fi
      fi
   done

   return 0
}

#--------------------------------------

run_script()
{
   local user=${3}
   if [[ -z $3 ]]
   then
      echo "INFO: running script ${1}"
      ${1} ${2}
      echo "INFO: ${1} success"
   else
      echo "INFO: running script ${1} as ${user}"
      /bin/su - ${user} -c "${1} ${2}"
      echo "FATAL: ${1} failed"
   fi

   return $?
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
#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

   if [[ ${deviceAction} != auto-detect ]]
   then
      #--------------------------------------
      # Get device info, import variables
      eval $( udevadm info --path=${devicePath} | \
         grep '=' | sed -e "s/E: //" -e "s/=/='/" -e "s/$/\'/" )
   fi

   #--------------------------------------
   # Check if VendorID is Supported
   pass=false
   for vendorId in ${supportedVendors}
   do
      if [[ ${ID_VENDOR_ID} == ${vendorId} ]]
      then
         pass=true ; break
      elif [[ ${deviceAction} == auto-detect ]] && lsusb | grep -q ${vendorId}
      then
         pass=true ; break
      fi
   done

   if ! ${pass}
   then
      remove_debug_file
      exit 1
   fi

   #--------------------------------------
   # Check if ProductID is Supported
   pass=false
   for productId in ${supportedProducts}
   do
      if echo ${PRODUCT} | grep -q ${productId}
      then
         deviceAction=docked
         pass=true ; break
      elif [[ ${deviceAction} == auto-detect ]] && lsusb | grep -q ${productId}
      then
         pass=true ; break
      fi
   done

   if ! ${pass}
   then
      remove_debug_file
      exit 2
   fi

   #--------------------------------------
   # We've gotten this far, it's supported. Lets log that
   deviceName=$( lsusb -d ${vendorId}:${productId} \
      | awk '{ for (i=7; i<=NF; i++) printf("%s ",$i) }END{ print"" }' )
   echo "INFO: Found Supported Thinkpad Dock - " \
      "${vendorId}:${productId} ${deviceName}"

   run_user_scripts

   exit $?

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------
