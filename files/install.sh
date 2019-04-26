#!/bin/sh
######################################################################
# 
# PowerChute Network Shutdown v.4.3.0
# Copyright (c) 1999-2018 Schneider Electric, All Rights Reserved. 
#
######################################################################


######################################################################
# Global Constants
######################################################################
PCNS_TAR="pcns430.tar"
PCNS_ZIP="$PCNS_TAR.gz"
JRE_VERSION="jre-11.0.1"
JRE_TGZ_FILE="jre-11.0.1_linux-x64_bin.tar.gz"
JRE_REQUIRED_MAJOR=1
JRE_REQUIRED_MINOR=8
JRE_REQUIRED_MINI=0
JRE_REQUIRED_MICRO=0
LINUX="Linux"
SOLARIS="Solaris"
HPUX="HP-UX"
AIX="AIX"
VIMA="VIMA"
UNKNOWN="UNKNOWN"
XENSERVER="XenServer"
x86_64="x86_64"
GROUP1="group1"
GROUP2="group2"
GROUP3="group3"
ARCH="x64"

TRUE=0
FALSE=1
STR_YES="YES"
YES=0
NO=1
QUIT=2
INVALID=99
PATH=/sbin:$PATH

######################################################################
# Exit Codes
######################################################################
EXIT_SUCCESS=0
EXIT_USAGE=1
EXIT_NOT_ROOT_USER=4
EXIT_UNSUPPORTED_OS=5
EXIT_UPGRADE_NOT_SUPPORTED=6
EXIT_USER_ABORT=7
EXIT_CONFLICT_PCPLUS=8
EXIT_CONFLICT_PCBE=9
EXIT_CONFLICT_PCS=10
EXIT_CONFLICT_VMWARE=11
EXIT_INVALID_INSTALL_DIR=12
EXIT_INVALID_JAVA_VERSION=13
EXIT_INVALID_LOCALE=14
EXIT_ZIPFILE_MISSING=15
EXIT_SILENT_CONFIG_MISSING=16
EXIT_EULA_NOT_ACCEPTED=17
EXIT_SILENT_INSTALL_JAVA_DIR=20

######################################################################
# Global Variables
######################################################################
UPDATE_INSTALL=$FALSE
OS=$UNKNOWN
SILENT_MODE=$FALSE

SRC_DIR=""
INSTALL_DIR=""
APP_DIR=""
JAVA_DIR=""
ACCEPT_EULA="NO"
REGISTER_NMC="NO"
STARTUP=""
SYSV_STARTUP=""
PCBE_STARTUP=""
PCS_STARTUP=""
OLD_INSTALL_DIR=""
JRE_FILE=""
SPARC=$FALSE
TR="tr"
SYSTEMCTL=$(which systemctl)
CHKCONFIG=$(which chkconfig)

######################################################################
#  Functions
######################################################################

# trap keyboard interrupt on the following:
# 1 SIGHUP
# 2 SIGINT
# 3 SIGQUIT
# 6 SIGABRT
trap control_c 1 2 3 6

control_c()
# run if user hits control-c
{
  echo -en "\n*** User Abort Detected! Exiting ***\n"
  Echo "Aborting with error code-$EXIT_USER_ABORT"
  CancelAll $EXIT_USER_ABORT
}

# Waits for user key press.
Pause() {
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty $OLDCONFIG
}

Echo() {
    string="$1"
    echo "$string"
}

PrintUsage() {
    Echo "Usage:"
    Echo "  $0 [-f <config file>] : Silent install with configuration file."
    Echo "  $0 [-h|-H] : Print help."
    exit $EXIT_USAGE
}

IsYN() {
    rval=$INVALID
    query_string="$1"
    loop=$TRUE
    while [ $loop -eq $TRUE ]
    do
        Echo ""
        Echo "$query_string "
        read ynq
        case "$ynq" in
        [Yy]*)
            rval=$YES
            loop=$FALSE
            ;;
        [Nn]*)
            rval=$NO
            loop=$FALSE
            ;;
        *)
            Echo "Invalid response."
            ;;
        esac
    done
    return $rval
}

SetSilentConfig() {
    # Check parameter
    cnt=`grep '^INSTALL_DIR=' $SILENT_CONFIG | wc -l`
    if [ $cnt -gt 1 ]; then
	    Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
        Echo "Error: Too many INSTALL_DIR in $SILENT_CONFIG"
        exit $EXIT_INVALID_INSTALL_DIR
    fi
    cnt=`grep '^JAVA_DIR=' $SILENT_CONFIG | wc -l`
    if [ $cnt -gt 1 ]; then
	    Echo "Aborting with error code-$EXIT_SILENT_INSTALL_JAVA_DIR"
        Echo "Error: Too many JAVA_DIR in $SILENT_CONFIG"
        exit $EXIT_SILENT_INSTALL_JAVA_DIR
    fi

    # Get values from config file
    INSTALL_DIR=`grep '^INSTALL_DIR=' $SILENT_CONFIG | sed s/INSTALL_DIR=//`
    JAVA_DIR=`grep '^JAVA_DIR=' $SILENT_CONFIG | sed s/JAVA_DIR=//`
    ACCEPT_EULA=`grep '^ACCEPT_EULA=' $SILENT_CONFIG | sed s/ACCEPT_EULA=// | sed 's/[^a-zA-Z]*//g' | $TR "[:lower:]" "[:upper:]" `
    REGISTER_NMC=`grep '^REGISTER_WITH_NMC=' $SILENT_CONFIG | sed s/REGISTER_WITH_NMC=// | $TR "[:lower:]" "[:upper:]" `

    # Verify INSTALL_DIR
    if [ -n "$INSTALL_DIR" ]; then
        # Collapse multiple slashes on the path
        INSTALL_DIR=`echo $INSTALL_DIR | tr -s /`
    
        # Remove trailing slash (if any)
        buf=`echo $INSTALL_DIR | grep '/$' `
        if [ -n "$buf" ]; then
            INSTALL_DIR=`echo $INSTALL_DIR | sed 's/\/*$//'`
        fi
        
        # Ensure leading slash
        buf=`echo $INSTALL_DIR | grep '^/' ` 
        if [ -z "$buf" ]; then
		    Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
            Echo "Error: INSTALL_DIR must start with '/'"
            exit $EXIT_INVALID_INSTALL_DIR
        fi
        
        # Ensure no white space on path
        buf=`echo $INSTALL_DIR | grep ' ' ` 
        if [ -n "$buf" ]; then
		    Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
            Echo "Error: INSTALL_DIR must not contain white space."
            exit $EXIT_INVALID_INSTALL_DIR
        fi
        
        # Ensure no backslashes on path
        buf=`echo $INSTALL_DIR | grep '\\\' ` 
        if [ -n "$buf" ]; then
		    Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
            Echo "Error: INSTALL_DIR must not contain back slash '\\'"
            exit $EXIT_INVALID_INSTALL_DIR
        fi
        
        Echo "INSTALL_DIR=$INSTALL_DIR"
    else
        buf=`grep '^INSTALL_DIR=' $SILENT_CONFIG`
        buf2=`grep '^#INSTALL_DIR=' $SILENT_CONFIG`
        if [ -n "$buf" -o -n "$buf2" ]; then
            Echo "INSTALL_DIR is not specified."
            Echo "PCNS will be installed to the default directory \"/opt/APC/PowerChute\""
            Echo ""
        else
		    Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
            Echo "Error: INSTALL_DIR is not configured"
            exit $EXIT_INVALID_INSTALL_DIR
        fi
    fi
    # Verify JAVA_DIR
    if [ -n "$JAVA_DIR" ]; then

        #must have / at the end, so add it    
        buf=`echo $JAVA_DIR | grep '/$' ` 
        if [ -z "$buf" ]; then
           JAVA_DIR="$JAVA_DIR/bin/"
        fi

        # Add "/bin" at the end of JAVA_DIR if needed for backwards compatibility
        
        buf=`echo $JAVA_DIR | grep '/bin/$' ` 
        if [ -z "$buf" ]; then
               JAVA_DIR="$JAVA_DIR/bin/"
        fi
        buf=`echo $JAVA_DIR | grep '^/' ` 
        if [ -z "$buf" ]; then
            Echo "Error: JAVA_DIR must start with /"
			Echo "Aborting with error code-$EXIT_SILENT_INSTALL_JAVA_DIR"
            exit $EXIT_SILENT_INSTALL_JAVA_DIR
        fi
        
        buf=`echo $JAVA_DIR | grep ' ' ` 
        if [ -n "$buf" ]; then
            Echo "Error: JAVA_DIR must not contain white space \" \""
			Echo "Aborting with error code-$EXIT_SILENT_INSTALL_JAVA_DIR"
            exit $EXIT_SILENT_INSTALL_JAVA_DIR
        fi
        
        buf=`echo $JAVA_DIR | grep '\\\' ` 
        if [ -n "$buf" ]; then
            Echo "Error: JAVA_DIR must not contain back slash \"\\\""
			Echo "Aborting with error code-$EXIT_SILENT_INSTALL_JAVA_DIR"
            exit $EXIT_SILENT_INSTALL_JAVA_DIR
        fi
        if [ ! -d "$JAVA_DIR" ]; then
            Echo "Error: Invalid JAVA_DIR. $JAVA_DIR does not exist."
			Echo "Aborting with error code-$EXIT_SILENT_INSTALL_JAVA_DIR"
            exit $EXIT_SILENT_INSTALL_JAVA_DIR
        fi
        Echo "JAVA_DIR=$JAVA_DIR"
    fi
}

IsSilentMode() {
    Echo "IsSilentMode"
}

IsRootUser() {
    ROOT="root"
    case "$OS" in    
    $SOLARIS)
        id | grep root > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            USER=$ROOT
        fi
        ;;
    *)
        USER=`id -nu`
        ;;
    esac
    
    if [ $USER != $ROOT ]; then
        Echo "Error: $0 must be run with root privileges!"
		Echo "Aborting with error code-$EXIT_NOT_ROOT_USER"
        exit $EXIT_NOT_ROOT_USER
    fi
}

CheckOS() {
    OS=`uname | grep -i Linux`
    if [ ! -z "$OS" ]; then
        # We're a Linux derivative, decide which one.
        if [ -f /etc/vima-release ] || [ -f /etc/vma-release ]; then
            OS=$VIMA
        else 
            grep XenServer /etc/redhat-release > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                OS=$XENSERVER
            else
                OS=$LINUX
            fi
        fi
    else
        OS=`uname | grep -i HP-UX`
        if [ ! -z "$OS" ] 
        then
            OS=$HPUX
        else
            OS=`uname | grep -i AIX`
            if [ ! -z "$OS" ] 
            then
                OS=$AIX
            else
                OS=`uname | grep -i SOLARIS`
                if [ ! -z "$OS" ]
                then
                    OS=$SOLARIS
                    isSparc
                    SPARC=$?
                else 
                    OS=`uname | grep -i SUNOS`
                    if [ ! -z "$OS" ]
                    then
                        OS=$SOLARIS
                        isSparc
                        SPARC=$?                        
                    else
					    Echo "Aborting with error code-$EXIT_UNSUPPORTED_OS"
                        Echo "Error: Unknown OS."
                        exit $EXIT_UNSUPPORTED_OS
                    fi
                fi
            fi
        fi
    fi
    Echo "OS=$OS"
    Echo ""
}

isSparc() {
    rval=$FALSE
    tmp=`uname -a | grep -i SPARC`
    if [ ! -z "$tmp" ] 
    then
        rval=$TRUE
    fi
    return $rval
}                        

Initialize() {
    Echo "Initializing ..."
    case "$OS" in
    $VIMA)
	Echo "This version of PowerChute Network Shutdown does not support VMWare ESX or ESXi."
	Echo "Please consult www.apc.com for the required version of PowerChute Network Shutdown."
	    Echo "Aborting with error code-$EXIT_UNSUPPORTED_OS"
        CancelAll $EXIT_UNSUPPORTED_OS
        ;;
    $XENSERVER)
        STARTUP=/etc/rc.d/init.d/PowerChute
        PCBE_STARTUP=/etc/rc.d/init.d/PBEAgent
        PCS_STARTUP=/etc/rc.d/init.d/pcs
        ;;
    $LINUX)
        if [ -f /etc/vmware-release ] ; then
	    	Echo "This version of PowerChute Network Shutdown does not support VMWare ESX or ESXi."
	    	Echo "Please consult www.apc.com for the required version of PowerChute Network Shutdown."
			Echo "Aborting with error code-$EXIT_UNSUPPORTED_OS"
            CancelAll $EXIT_UNSUPPORTED_OS
        fi
        
        STARTUP=/usr/bin/PowerChute
        SYSV_STARTUP=/etc/init.d/PowerChute
        PCBE_STARTUP=/etc/rc.d/init.d/PBEAgent
        PCS_STARTUP=/etc/rc.d/init.d/pcs
        ;;
    $SOLARIS)
        STARTUP=/etc/rc2.d/S99PowerChute
        PCBE_STARTUP=/etc/rc2.d/S99PBEAgent
        TR=/usr/xpg4/bin/tr
        ;;
    $HPUX)
        STARTUP=/sbin/init.d/pcns
        ;;
    $AIX)
        STARTUP=/etc/rc.APCpcns
        ;;
    esac
}

IsPCNSInstalled() {
    upgrade=$FALSE    
    version="Unknown"
    SCRIPT=""
    
    # Check for the SystemD startup script
    if [ -f "$STARTUP" ]; then
    	SCRIPT="$STARTUP"
    	
    	grep 'PowerChute Network Shutdown, v4.3.0' $SCRIPT 1>/dev/null 2>/dev/null
    	if [ $? = 0 ]; then
	    	Echo "Found PowerChute Network Shutdown v4.3.0."
            version="4.3.0"
            upgrade=$TRUE
        fi	
        
    elif [ -f "$SYSV_STARTUP" ]; then
    	SCRIPT="$SYSV_STARTUP"
    	
    
	    grep 'PowerChute Network Shutdown, v2.2.4' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v2.2.4."
            version="2.2.4"
            upgrade=$FALSE
        fi
        
        grep 'PowerChute Network Shutdown, v2.2.5' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v2.2.5."
            version="2.2.5"
            upgrade=$FALSE
        fi
        
        grep 'PowerChute Network Shutdown, v2.2.6' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v2.2.6."
            version="2.2.6"
            upgrade=$FALSE
        fi
        
        grep 'PowerChute Network Shutdown, v2.2.7' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v2.2.7."
            version="2.2.7"
            upgrade=$FALSE
        fi
        
		grep 'PowerChute Network Shutdown, v3.0.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v3.0.0"
            version="3.0.0"
            upgrade=$FALSE
        fi
		
        grep 'PowerChute Network Shutdown, v3.0.1' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v3.0.1"
            version="3.0.1"
            upgrade=$FALSE
        fi
        
        grep 'PowerChute Network Shutdown, v3.1.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v3.1.0"
            version="3.1.0"
            upgrade=$FALSE
        fi
        
        grep 'PowerChute Network Shutdown, v3.2.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v3.2.0"
            version="3.2.0"
            upgrade=$FALSE
        fi

        grep 'PowerChute Network Shutdown, v4.0.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v4.0.0"
            version="4.0.0"
            upgrade=$FALSE
        fi
		
		grep 'PowerChute Network Shutdown, v4.1.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v4.1.0"
            version="4.1.0"
            upgrade=$TRUE
        fi

		grep 'PowerChute Network Shutdown, v4.2.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v4.2.0"
            version="4.2.0"
            upgrade=$TRUE
        fi

		grep 'PowerChute Network Shutdown, v4.3.0' $SCRIPT 1>/dev/null 2>/dev/null
        if [ $? = 0 ]; then
            Echo "Found PowerChute Network Shutdown v4.3.0"
            version="4.3.0"
            upgrade=$TRUE
        fi    
    fi

	if [ -n "$SCRIPT" ]; then    
		if [ $upgrade = $FALSE ]; then
			Echo "PowerChute Network Shutdown is already installed. Upgrade is not supported for this version."
		    Echo "Please uninstall existing PowerChute Network Shutdown to continue with installation of PowerChute Network Shutdown v.4.3.0"
		    Echo "Installation cancelled."
			Echo "Aborting with error code-$EXIT_UPGRADE_NOT_SUPPORTED"
			Echo ""
		    exit $EXIT_UPGRADE_NOT_SUPPORTED
		fi	        

		result=$FALSE
	    while [ $result = $FALSE ]
	    do
	        prev_install_dir=`grep '^INSTALL_PATH='  $SCRIPT | sed s/INSTALL_PATH=\"// | sed s/\"//`
	        if [ -d "$prev_install_dir/$GROUP2" ]; then
	            Echo "Previous version of PowerChute Network Shutdown is installed."
	            Echo "Update install does not support multiple instances."
	            Echo "Please uninstall PCNS and run this install program again."
				Echo "Aborting with error code-$EXIT_UPGRADE_NOT_SUPPORTED"
	            Echo "Installation cancelled."
	            Echo ""
	            exit $EXIT_UPGRADE_NOT_SUPPORTED
	        fi
	        if [ $SILENT_MODE = $TRUE ]; then
	            if [ $version = "4.3.0" ]; then
					Echo "Current version of PowerChute Network Shutdown is installed. $version"
				else
					Echo "Previous version of PowerChute Network Shutdown is installed. $version"
				fi
	            Echo "Start update installation."
	            val=$YES
	        else
	            if [ $version = "4.3.0" ]; then
					Echo "Current version of PowerChute Network Shutdown is installed. $version"
				else
					Echo "Previous version of PowerChute Network Shutdown is installed."
				fi
	            IsYN "Do you want to update it [Yes|No]?"
	            val=$?
	        fi
	        case $val in
	        $YES)
	            Echo "Update selected for existing version of PowerChute Network Shutdown."
	            UPDATE_INSTALL=$TRUE
	            result=$TRUE
	            ;;
	        $NO)
	            Echo "Installation cancelled."
				Echo "Aborting with error code-$EXIT_USER_ABORT"
	            Echo ""
	            exit $EXIT_USER_ABORT
	            ;;
	        *)
	            Echo "Invalid response."
	            ;;
	        esac
	    done
	fi     
    
}

IsPCPlusInstalled() {
    if [ -d "/etc/apc_repository" ]; then
        Echo "PowerChute Plus is installed. Please uninstall PowerChute Plus."
		Echo "Aborting with error code-$EXIT_CONFLICT_PCPLUS"
        exit $EXIT_CONFLICT_PCPLUS
    fi
}

IsPCBEInstalled() {
	pcbeInstalled=0
	# Check with systemctl (if available) ...
    if [ -n "$SYSTEMCTL" ]; then
         $SYSTEMCTL is-enabled PBEAgent.service 1>/dev/null 2>/dev/null
         if [ $? -eq 0 ]; then
         	pcbeInstalled=1
         fi
    fi
    	
	# Otherwise check for 'old style' startup script
    if [ -n "$PCBE_STARTUP" -a -f "$PCBE_STARTUP" ]; then
    	pcbeInstalled=1	  
    fi
    
    if [ $pcbeInstalled -eq 1 ]; then
	    Echo "Aborting with error code-$EXIT_CONFLICT_PCBE."
        Echo "PowerChute Business Edition Agent is installed. Please uninstall PCBE Agent."
        exit $EXIT_CONFLICT_PCBE
    fi
}

IsPCSInstalled() {
    if [ -n "$PCS_STARTUP" -a -f "$PCS_STARTUP" ]
    then
        Echo "PowerChute Server is installed. Please uninstall PowerChute Server."
		Echo "Aborting with error code-$EXIT_CONFLICT_PCS."
        exit $EXIT_CONFLICT_PCS
    fi
}

checkForVMWare() {
    lang='ja_'
    if env | grep ^LANG=$lang &>/dev/null;
    then
       if [ -e /usr/bin/vmware ]
       then
           # VMware detected!
           
           # Check for VMware Server
           if /usr/bin/vmware -v | grep Server &> /dev/null
           then
                Echo "VMware Server has been detected on your system. This version of PowerChute Network Shutdown does not support VMware. Please uninstall VMware Server, or consult www.apc.com for the required version of PowerChute Network Shutdown."
				Echo "Aborting with error code-$EXIT_CONFLICT_VMWARE."
                exit $EXIT_CONFLICT_VMWARE
           fi
           
           # Check for VMware Workstation
           if /usr/bin/vmware -v | grep Workstation &> /dev/null
           then
                Echo "VMware Workstation has been detected on your system. This version of PowerChute Network Shutdown does not support VMware. Please uninstall VMware Workstation, or consult www.apc.com for the required version of PowerChute Network Shutdown."
				Echo "Aborting with error code-$EXIT_CONFLICT_VMWARE."
                exit $EXIT_CONFLICT_VMWARE
           fi
       fi
       
       # Check for VMware-Player
       if [ -e /usr/bin/vmplayer ]
       then
           # VMware Player detected.
            Echo "VMware Player has been detected on your system. This version of PowerChute Network Shutdown does not support VMware. Please uninstall VMware Player, or consult www.apc.com for the required version of PowerChute Network Shutdown."
			Echo "Aborting with error code-$EXIT_CONFLICT_VMWARE."
            exit $EXIT_CONFLICT_VMWARE
       fi

     fi
}

checkForXenServer() {
    grep XenServer /etc/redhat-release > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        Echo "Xen Server has been detected on your system."
        Echo "This version of PowerChute Network Shutdown does not support Xen Server."
        Echo "Please consult www.apc.com for the required version of PowerChute Network Shutdown."
		Echo "Aborting with error code-$EXIT_CONFLICT_VMWARE."
        exit $EXIT_CONFLICT_VMWARE
    fi
}

InitUpdate() {
    if [ $UPDATE_INSTALL = $TRUE ]; then
        # Get PCNS Path
        if [ -f "$STARTUP" ]; then
        	OLD_INSTALL_DIR=`grep '^INSTALL_PATH='  $STARTUP | sed s/INSTALL_PATH=\"// | sed s/\"//`
        elif [ -f "$SYSV_STARTUP" ]; then
        	OLD_INSTALL_DIR=`grep '^INSTALL_PATH='  $SYSV_STARTUP | sed s/INSTALL_PATH=\"// | sed s/\"//`
        fi
        Echo "PowerChute Network Shutdown previously installed at:$OLD_INSTALL_DIR" 
        # Stop daemon
        case "$OS" in
        $VIMA)
            /etc/rc.d/init.d/PowerChute stop
            ;;
        $XENSERVER)
            /etc/rc.d/init.d/PowerChute stop
            ;;
        $LINUX)
        	if [ -f /usr/bin/PowerChute ]; then
        		/usr/bin/PowerChute stop
        	fi
        	
			if [ -f /etc/init.d/PowerChute ]; then
            	/etc/init.d/PowerChute stop
			fi

            if [ -f /etc/rc.d/init.d/PowerChute ]; then
            	/etc/rc.d/init.d/PowerChute stop
           	fi
            ;;
        $SOLARIS)
            /etc/rc2.d/S99PowerChute stop
            ;;
        $HPUX)
            /sbin/init.d/pcns stop
            ;;
        $AIX)
            /etc/rc.APCpcns stop
            ;;
        esac
    fi
}

BackupOldPCNS() {
    if [ $UPDATE_INSTALL = $TRUE ]; then
        # Install dir is same as old PCNS
        if [ "$INSTALL_DIR/PowerChute" = "$OLD_INSTALL_DIR" ]; then
            backup_dir="$INSTALL_DIR/PowerChute_update_backup"
            rm -rf $backup_dir
            mv $OLD_INSTALL_DIR $backup_dir
            mkdir -p $OLD_INSTALL_DIR
            OLD_INSTALL_DIR=$backup_dir
            Echo "Backup old PCNS directory to $OLD_INSTALL_DIR"
        fi
    fi
}

UninstallOldPCNS() {
    if [ $UPDATE_INSTALL = $TRUE ]; then
        # remove all files
        rm -rf $OLD_INSTALL_DIR
    fi
}

CopyUpdateFiles() {
    if [ $UPDATE_INSTALL = $TRUE ]; then
        Echo "Copying update files ..."
        if [ -d "$OLD_INSTALL_DIR/$GROUP1" ]; then
            # PCNS 222
            backup_dir="$OLD_INSTALL_DIR/$GROUP1"
        else
            backup_dir="$OLD_INSTALL_DIR"
        fi
        
        # Restore backups of config files.
        cp "$backup_dir/m11.cfg" "$APP_DIR/$GROUP1/" 1>/dev/null 2>/dev/null
        cp "$backup_dir/EventLog.txt" "$APP_DIR/$GROUP1/" 1>/dev/null 2>/dev/null
		cp "$backup_dir/pcnsconfig.ini" "$APP_DIR/$GROUP1/" 1>/dev/null 2>/dev/null
		cp "$backup_dir/pcnsconfig_backup.ini" "$APP_DIR/$GROUP1/" 1>/dev/null 2>/dev/null
		
		# Convert config files
		cd $APP_DIR/$GROUP1/
		javaParams="-Xms32m -Xmx64m -Dfile.encoding=UTF-8 -cp .:lib/*:comp/pcns.jar -DapplicationDirectory=$APP_DIR --add-opens java.xml/com.sun.org.apache.xerces.internal.parsers=ALL-UNNAMED com.apcc.pcns.configservice.UpgradeIniConverter"
        #Echo ${JAVA_DIR}java  $javaParams
        ${JAVA_DIR}java  $javaParams 1>/dev/null 2>/dev/null
       
        cd $oldDir
    fi
}

SetInstallDir() {
    if [ $SILENT_MODE = $TRUE ]; then
        if [ -z "$INSTALL_DIR" ]; then
            INSTALL_DIR="/opt/APC"
        fi
    elif [ $UPDATE_INSTALL = $TRUE ]; then
        # Use the old location
        INSTALL_DIR=`dirname $OLD_INSTALL_DIR`
    else
        res=$FALSE
        while [ $res = $FALSE ]
        do
            Echo ""
            Echo "Please enter the installation directory or press enter to install to the default directory (/opt/APC/PowerChute):"
            read val
            if [ -z "$val" ]; then
                INSTALL_DIR="/opt/APC"    
            else
                INSTALL_DIR=$val    
                # Verify install path
                if [ -n "$INSTALL_DIR" ]; then
                    buf=`echo $INSTALL_DIR | grep '^/' ` 
                    if [ -z "$buf" ]; then
                        Echo "Installation directory must start with \"/\""
						Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
                        exit $EXIT_INVALID_INSTALL_DIR
                    fi
                    buf=`echo $INSTALL_DIR | grep ' ' ` 
                    if [ -n "$buf" ]; then
                        Echo "Installation directory must not contain white space \" \""
						Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
                        exit $EXIT_INVALID_INSTALL_DIR
                    fi
                    buf=`echo $INSTALL_DIR | grep '\\\' ` 
                    if [ -n "$buf" ]; then
                        Echo "Installation directory must not contain back slash \"\\\""
						Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
                        exit $EXIT_INVALID_INSTALL_DIR
                    fi
                fi
            fi

            IsYN "Are you sure you want to install PCNS to $INSTALL_DIR/PowerChute [Yes|No]?"
            val=$?
            case $val in
            $YES)
                if [ -d "$INSTALL_DIR/PowerChute" ]; then
                    IsYN "$INSTALL_DIR/PowerChute already exists. Do you want to use it [Yes|No]?"
                    val=$?
                    case $val in
                    $YES)
                        BackupOldPCNS
                        res=$TRUE
                        ;;
                    $NO)
                        ;;
                    *)
                        Echo "Invalid response."
                        ;;
                    esac
                else
                    res=$TRUE
                fi
                ;;
            $NO)
                ;;
            *)
                Echo "Invalid response."
                ;;
            esac
        done
    fi

    if [ ! -d "$INSTALL_DIR" ]; then
        Echo "Creating $INSTALL_DIR directory ..."
        mkdir -p "$INSTALL_DIR"
        if [ ! $? = 0 ]; then
            Echo "Failed to create directory $INSTALL_DIR."
				Echo "Aborting with error code-$EXIT_INVALID_INSTALL_DIR"
            exit $EXIT_INVALID_INSTALL_DIR
        fi
    fi
    Echo "PCNS will be installed to $INSTALL_DIR/PowerChute"
}

CheckBundledJava() {
    rval=$FALSE
    case "$OS" in
    $VIMA)
        JRE_FILE=$JRE_TGZ_FILE
        ;;
    $LINUX)
        JRE_FILE=$JRE_TGZ_FILE
        ;;
    $SOLARIS)
        if [ $SPARC = $TRUE ]; then
            JRE_FILE=$JRE_TGZ_FILE"-solaris-sparc.tar.gz"            
        else
            JRE_FILE=$JRE_TGZ_FILE"-solaris-i586.tar.gz"
        fi
        ;;
    $XENSERVER)
        JRE_FILE=$JRE_TGZ_FILE
        ;;
    $HPUX)
        ;;
    $AIX)
        ;;
    esac
    if [ -f "$SRC_DIR/$JRE_FILE" ]; then
        rval=$TRUE
    fi
    return $rval
}

AskJavaPath() {
    CheckBundledJava
    bundled=$?
    res=$FALSE
    while [ $res = $FALSE ]
    do
        Echo ""
        if [ $bundled = $TRUE ];then
            Echo "Please enter java directory if you want to use your system java (example:/usr/local/bin/jre/$JRE_VERSION) or press enter to install the bundled Java:"
        else
            Echo "JRE is not bundled. Please enter your java directory (example:/usr/local/bin/jre/$JRE_VERSION):"
        fi
        
        read str
                
        if [ $bundled = $TRUE -a -z "$str" ]; then
            #the empty string is ok, means use the path JRE
            JAVA_DIR=""
            res=$TRUE
        else
            JAVA_DIR=$str
            res=$FALSE
        fi
        
        if [ $res = $FALSE -a -n "$JAVA_DIR" ]; then
            #must have / at the end, so add it    
            buf=`echo $JAVA_DIR | grep '/$' ` 
            if [ -z "$buf" ]; then
                  JAVA_DIR="${JAVA_DIR}/"
            fi
        
            # Add/bin at the end of JAVA_DIR if needed
            # This allows it to be backward compatible
            # with previous versions, which did not have 
            # the bin
            buf=`echo $JAVA_DIR | grep '/bin/$' ` 
            if [ -z "$buf" ]; then
                   JAVA_DIR="$JAVA_DIR/bin/"
            fi
            
            buf=`echo $JAVA_DIR | grep ' ' ` 
            if [ -n "$buf" ]; then
                Echo "Java directory must not contain white space \" \""
            else
                buf=`echo $JAVA_DIR | grep '^/' ` 
                if [ -z "$buf" ]; then
                    Echo "Java directory must start with /"
                else
                    buf=`echo $JAVA_DIR | grep '\\\' ` 
                    if [ -n "$buf" ]; then
                        Echo "Java directory must not contain back slash \"\\\""
                    elif [ ! -d $JAVA_DIR ]; then
                        Echo "Invalid path: $JAVA_DIR"
                    else                                      
                        #Check the java version before confirming, no point in 
                        #asking them if they want it is we can't accept it anyway.
                         CheckJavaVersion
                         res=$?                        
                    fi
                fi
            fi            
         fi 
    done
}

InstallBundledJava() {
    CheckBundledJava
    if [ $? = $FALSE ]; then
        Echo "No private JRE is bundled for this OS.  Please install and specify a JRE"
		Echo "Aborting with error code-$EXIT_INVALID_JAVA_VERSION."
        CancelAll $EXIT_INVALID_JAVA_VERSION
    fi 
    
    # Copy jre file
	APP_JRE_DIR=$APP_DIR/$JRE_VERSION
	JAVA_DIR="$APP_DIR/$JRE_VERSION/bin/"

    Echo "Copying jre to $APP_DIR ..."
    mkdir -p $APP_DIR
    cp "$SRC_DIR/$JRE_FILE" "$APP_DIR/jre.tar.gz"
    if [ ! $? -eq 0 ]; then
        Echo "Failed to copy jre file."
        CancelAll
    fi
    cd $APP_DIR
    chmod 700 jre.tar.gz

    # Extract Java
    Echo "Extracting jre to $APP_DIR/jre ..."
    gunzip jre.tar.gz
    tar -xf jre.tar
    if [ ! $? -eq 0 ]; then
        Echo "Failed to extract jre file."
        CancelAll
    fi
    rm -rf jre.tar
	chmod -R 0755 $APP_JRE_DIR
    
    # Regenerating the Shared Archive
    if [ ! $OS = "$VIMA" ]; then
        $JAVA_DIR/java -Xshare:dump 1>/dev/null 2>/dev/null
    fi
    cd $APP_DIR
}

CheckJavaVersion() {
    Echo "Checking version of Java ..."
    rval=$FALSE

    # Show JRE Version
    ${JAVA_DIR}java -version >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then 
        Echo 
        Echo "Java not found at ${JAVA_DIR}."
    else
        VERSION=`${JAVA_DIR}java -version 2>&1 | head -n 1 | cut -d\" -f 2 | sed s/_/\./g`
        Echo "Detected Java Version: $VERSION"

        MAJOR=`echo $VERSION | cut -d\. -f 1`
        MINOR=`echo $VERSION | cut -d\. -f 2`
        MINI=`echo $VERSION | cut -d\. -f 3`
        MICRO=`echo $VERSION | cut -d\. -f 4`
		#remove any non integers
		MICRO=`echo $MICRO | sed 's/[^0-9]*//g'`		
		
        if [ -z "$MICRO" ]; then
            MICRO=0
        fi
        
        case "$OS" in
        $HPUX)
            JRE_REQUIRED_MICRO=08
            ;;
        *) 
            JRE_REQUIRED_MICRO=0
            ;;
        esac
        
        if [ $VERSION ]; then
            if [ \( $MAJOR -gt $JRE_REQUIRED_MAJOR \) -o \( $MAJOR -eq $JRE_REQUIRED_MAJOR -a $MINOR -gt $JRE_REQUIRED_MINOR \) -o \( $MAJOR -eq $JRE_REQUIRED_MAJOR -a $MINOR -eq $JRE_REQUIRED_MINOR -a $MINI -gt $JRE_REQUIRED_MINI \) -o \( $MAJOR -eq $JRE_REQUIRED_MAJOR -a $MINOR -eq $JRE_REQUIRED_MINOR -a $MINI -eq $JRE_REQUIRED_MINI -a "$MICRO" -ge "$JRE_REQUIRED_MICRO" \) ]; then
                Echo "Acceptable version"
                rval=$TRUE
            else
                Echo "Wrong version of Java ($MAJOR.$MINOR.$MINI.$MICRO).  Minimum Java version required is $JRE_REQUIRED_MAJOR.$JRE_REQUIRED_MINOR.$JRE_REQUIRED_MINI.$JRE_REQUIRED_MICRO "
                Echo "Java can be downloaded from www.java.com"
            fi
        else
            Echo 
            Echo "Java not found at $JAVA_DIR"
        fi
    fi
    return $rval
}


CheckOSArch(){
	tmp=`uname -a | grep -e _64 -e ia64`
	if [ ! -z "$tmp" ]; then
		#it is a 64 bit OS
		if [ "$ARCH" = "x32" ]; then
			echo "64 bit OS detected.  This installer is for 32 bit OS. Please download the 64 bit installer for this OS"
			CancelAll
		fi  
	else
		#It is a 32 bit OS
		if [ "$ARCH" = "x64" ]; then
			echo "32 bit OS detected.  This installer is for 64 bit OS. Please download the 32 bit installer for this OS"
			CancelAll
		fi  
	fi
}

SetupJava() {
    if [ $SILENT_MODE = $TRUE ]; then
        if [ -z "$JAVA_DIR" ]; then
            InstallBundledJava
            res=$TRUE
        else
            CheckJavaVersion
            res=$?
            
            if [ $res -eq $FALSE ]; then
                # invalid java path
				Echo "Aborting with error code-$EXIT_INVALID_JAVA_VERSION."
                CancelAll $EXIT_INVALID_JAVA_VERSION
            fi
        fi        
    else

		#only ask for java path if there is no bundled java	    
		CheckBundledJava
	    if [ $? = $FALSE ]; then
        AskJavaPath
        fi

	    if [ -z "$JAVA_DIR" ]; then	        
	    	InstallBundledJava
		fi
    fi

    # Show JRE Version
    Echo ""
    $JAVA_DIR/java -version
    if [ ! $? -eq 0 ]; then 
        Echo "" 
		CheckOSArch
        Echo "Invalid jre path."
		CancelAll
    fi
    Echo ""
    # Create java path config file
    Echo "JAVA_DIR=$JAVA_DIR"
    Echo ""
    cd "$SRC_DIR"
}

IsPortFree(){
        oldDir=$PWD
        cd $APP_DIR/$GROUP1
        javaParams="-Xms32m -Xmx64m -Dfile.encoding=UTF-8 -cp .:comp/pcns.jar:lib/m11.jar:lib/commons-codec-1.11.jar:lib/commons-collections-3.2.1.jar:lib/commons-configuration-1.6.jar:lib/commons-lang-2.6.jar:lib/commons-logging-1.1.1.jar:lib/log4j-core-2.10.0.jar:lib/log4j-api-2.10.0.jar:/lib/snmp4j-2.4.3.jar:/lib/snmp4j-agent-2.4.2.jar:lib/bcprov-jdk15on-160.jar:./lib/bcpkix-jdk15on-160.jar:lib/json_simple-1.1.jar:lib/jasypt-1.9.2.jar com.apcc.pcns.silentconfig.CheckPort $1"
        ${JAVA_DIR}java  $javaParams 
        code=$?
        cd $oldDir 
        if [ $code -ne 100 ]; then
            return $FALSE     
        fi
        return $TRUE
}

UpdateINI(){
        # Register with NMC
        oldDir=$PWD
        cd $APP_DIR/$GROUP1
        section="$1"
        values="$2"
        javaParams="-Xms32m -Xmx64m -Dfile.encoding=UTF-8 -cp .:comp/pcns.jar:lib/m11.jar:lib/commons-codec-1.11.jar:lib/commons-collections-3.2.1.jar:lib/commons-configuration-1.6.jar:lib/commons-lang-2.6.jar:lib/commons-logging-1.1.1.jar:lib/log4j-core-2.10.0.jar:lib/log4j-api-2.10.0.jar:lib/bcprov-jdk15on-160.jar:./lib/bcpkix-jdk15on-160.jar:lib/json_simple-1.1.jar:lib/jasypt-1.9.2.jar:lib/snmp4j-2.4.3.jar:lib/snmp4j-agent-2.4.2.jar -DsilentConfig=$SILENT_CONFIG -DsourceDir=\"$SRC_DIR\" -DapplicationDirectory=\"$APP_DIR\" -Dgroup=1 -Dupgrade=$upgrade com.apcc.pcns.silentconfig.iniConfig"
        ${JAVA_DIR}java $javaParams $section $values 2>/dev/null 1>/dev/null
        code=$?
        if [ $code -ne 0 ]; then
            Echo "Error applying configuration.  Error code is: $code"
            CancelAll $code
        fi
}        



SetupM11Cfg() {
   Echo "Setup the m11.cfg file"
   filename="$GROUP_DIR/m11.cfg"
   setting1="host.ApplicationDirectory=$GROUP_DIR"
   setting2="host.ComponentDirectory=$GROUP_DIR/comp"
   setting3="Notifier.NotifierExe=$GROUP_DIR/bin/notifier"

    #echo "DEBUG: $setting1"
    #echo "DEBUG: $setting2"
    #echo "DEBUG: $setting3"
    
    PARAMS=" -Dfile.encoding=UTF-8 -cp .:$GROUP_DIR/comp/pcns.jar:$GROUP_DIR/lib/m11.jar com.apcc.pcns.m11cfgInit.M11cfgInit $filename $setting1 $setting2 $setting3"
    #echo "DEBUG: ${JAVA_DIR}java $PARAMS"
   #Note:JAVA_DIR has the \ on the end
   ${JAVA_DIR}java $PARAMS 1>/dev/null 2>/dev/null
   
}

SetupCommandFiles() {
    case "$OS" in
    $VIMA)
        cp VIMA/notifier.sh notifier
        cp VIMA/shutdown.sh shutdown
        cp VIMA/shutdownhost.pl shutdownhost.pl
        chmod 744 shutdownhost.pl
        ;;
    $XENSERVER)
        cp Linux/notifier.sh notifier
        cp Linux/shutdown.sh shutdown
        ;;        
    $LINUX)
        cp Linux/notifier.sh notifier
        cp Linux/shutdown.sh shutdown
        if [ -n "$SYSTEMCTL" ]; then
        	cp Linux/PowerChute.service /etc/systemd/system
        	chmod 664 /etc/systemd/system/PowerChute.service
        fi
        ;;
    $SOLARIS)
        cp Solaris/notifier.sh notifier
        cp Solaris/shutdown.sh shutdown
        ;;
    $HPUX)
        cp Hpux/notifier.sh notifier
        cp Hpux/shutdown.sh shutdown
        ;;
    $AIX)
        cp Aix/notifier.sh notifier
        cp Aix/shutdown.sh shutdown
		cp Aix/shutdownScheduleOn.sh shutdownScheduleOn
        ;;
    esac    
    chmod 744 notifier
    chmod 744 shutdown
    rm -rf Linux Solaris Hpux Aix VIMA ESX XenServer
    cd "$APP_DIR"
}

SetupAllCommandFiles() {
    cd "$APP_DIR"
    if [ -d $GROUP1 ]; then
        cd ./$GROUP1/bin
        SetupCommandFiles
    else
        cd ./bin
        SetupCommandFiles
    fi
    cd "$APP_DIR"
}

ConfigureStartup() {
    APP_DIR_QUOTED=\"$APP_DIR\"
    group_dir_quoted=\"$GROUP_DIR\"

    # Update scripts
    if [ $OS = "$HPUX" ]; then
        sed -e "s:nohup:/bin/nohup:g" powerchute.sh > powerchute.sh.tmp$$
        mv -f powerchute.sh.tmp$$ powerchute.sh
    fi
    sed -e "s:GSUB_INSTALL_PATH:$APP_DIR_QUOTED:g" startup.sh > startup.sh.tmp$$
    sed -e "s:GSUB_INSTALL_PATH:$group_dir_quoted:g" powerchute.sh > powerchute.sh.tmp$$
    mv -f startup.sh.tmp$$ startup.sh
    cp powerchute.sh.tmp$$ $GROUP_DIR/powerchute.sh
    chmod 744 $GROUP_DIR/powerchute.sh
    rm -f *.tmp$$

    echo $JAVA_DIR > ${GROUP_DIR}/java.cfg
}

ConfigureAllStartup() {
    Echo "Configuring startup files ..."
    cd "$APP_DIR"
    
    if [ -d $GROUP1 ]; then
        GROUP_DIR="$APP_DIR/$GROUP1"
        ConfigureStartup
        rm -f powerchute.sh*
    else
        GROUP_DIR=$APP_DIR
        ConfigureStartup
    fi
    if [ -n "$SYSTEMCTL" ]; then
    	Echo "Startup script=$STARTUP"

    	cp startup.sh $STARTUP
    	chmod 0544 $STARTUP
    else 
    	Echo "Startup script=$SYSV_STARTUP"

    	cp startup.sh $SYSV_STARTUP
    	chmod 0544 $SYSV_STARTUP
    fi
    
    rm -f startup.sh
}

UninstallOldStartupLink() {
	if [ $UPDATE_INSTALL = $TRUE ]; then
    	if [ $OS = "$LINUX" ]; then
    		if [ -f "$SYSV_STARTUP" -a -n "$SYSTEMCTL" ]; then
    			rm -f $SYSV_STARTUP
    		fi
    	elif [ $OS = "$VIMA" -o $OS = "$XENSERVER" ]; then
    		Echo "Deleting Linux symbolic link ..."
	       	if [ -d /etc/rc0.d ]; then
	        	rm -f /etc/rc0.d/K99PowerChute
	            rm -f /etc/rc1.d/K99PowerChute
	            rm -f /etc/rc2.d/K99PowerChute
	            rm -f /etc/rc3.d/K99PowerChute
	            rm -f /etc/rc4.d/K99PowerChute
	            rm -f /etc/rc5.d/K99PowerChute
	            rm -f /etc/rc6.d/K99PowerChute
	         else
	            rm -f /etc/rc.d/rc0.d/*99PowerChute
	            rm -f /etc/rc.d/rc1.d/*99PowerChute
	            rm -f /etc/rc.d/rc2.d/*99PowerChute
	            rm -f /etc/rc.d/rc3.d/*99PowerChute
	            rm -f /etc/rc.d/rc4.d/*99PowerChute
	            rm -f /etc/rc.d/rc5.d/*99PowerChute
	            rm -f /etc/rc.d/rc6.d/*99PowerChute
	         fi
 		fi
    fi
}

ConfigureStartupLink() {
	if [ $OS = "$VIMA" -o $OS = "$XENSERVER" ]; then
     	Echo "Updating service symbolic link ..."
        if [ -n "$CHKCONFIG" ]; then
            $CHKCONFIG --add PowerChute
            $CHKCONFIG PowerChute on
        elif [ -d /etc/rc0.d ]; then
			if [ ! -L /etc/rc0.d/K99PowerChute ]; then
            	ln -s /etc/init.d/PowerChute /etc/rc0.d/K99PowerChute
            fi
            if [ ! -L /etc/rc1.d/K99PowerChute ]; then
            	ln -s /etc/init.d/PowerChute /etc/rc1.d/K99PowerChute
            fi
            if [ ! -L /etc/rc2.d/S99PowerChute ]; then
            	ln -s /etc/init.d/PowerChute /etc/rc2.d/S99PowerChute
            fi
            if [ ! -L /etc/rc3.d/S99PowerChute ]; then
            	ln -s /etc/init.d/PowerChute /etc/rc3.d/S99PowerChute
            fi
            if [ ! -L /etc/rc4.d/S99PowerChute ]; then
            	ln -s /etc/init.d/PowerChute /etc/rc4.d/S99PowerChute
			fi
			if [ ! -L /etc/rc5.d/S99PowerChute ]; then            	
            	ln -s /etc/init.d/PowerChute /etc/rc5.d/S99PowerChute
            fi
            if [ ! -L /etc/rc6.d/K99PowerChute ]; then
            	ln -s /etc/init.d/PowerChute /etc/rc6.d/K99PowerChute
            fi
        else
        	if [ ! -L /etc/rc.d/rc0.d/K99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc0.d/K99PowerChute
			fi
			if [ ! -L /etc/rc.d/rc1.d/K99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc1.d/K99PowerChute
            fi
            if [ ! -L /etc/rc.d/rc2.d/S99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc2.d/S99PowerChute
            fi
            if [ ! -L /etc/rc.d/rc3.d/S99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc3.d/S99PowerChute
            fi
            if [ ! -L /etc/rc.d/rc4.d/S99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc4.d/S99PowerChute
            fi
            if [ ! -L /etc/rc.d/rc5.d/S99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc5.d/S99PowerChute
            fi
            if [ ! -L /etc/rc.d/rc6.d/K99PowerChute ]; then
            	ln -s /etc/rc.d/init.d/PowerChute /etc/rc.d/rc6.d/K99PowerChute
            fi
        fi
    else
        case "$OS" in
        $LINUX)
        	if [ -n "$SYSTEMCTL" ]; then
        		Echo "Installing Service ..."
   	        	$SYSTEMCTL daemon-reload
				$SYSTEMCTL enable PowerChute.service
			fi
			
			if [ -n "$CHKCONFIG" ]; then
				$CHKCONFIG --add PowerChute
			fi
        	;;
        $SOLARIS)
            cp $STARTUP /etc/rc0.d/K99PowerChute
            ;;
        $HPUX)
            Echo "Updating HP-UX symbolic link ..."
            ln -s $STARTUP /sbin/rc1.d/K990pcns
            ln -s $STARTUP /sbin/rc2.d/S990pcns
            ;;
        $AIX)
            Echo "Updating AIX inittab ..."
            mkitab "PCNS:2:wait:$STARTUP start #PowerChute Network Shutdown" >/dev/null 2>&1
            ;;
        esac
    fi
}

ConfigureUninstall() {
    Echo "Configuring uninstall script ..."
    cd "$APP_DIR"
    APP_DIR_QUOTED=\"$APP_DIR\"
    sed -e "s:GSUB_INSTALL_PATH:$APP_DIR_QUOTED:g" uninstall > uninstall.tmp$$
    mv -f uninstall.tmp$$ uninstall
    chmod 0544 uninstall 
}

ConfigureOwner() {
    chown -R root "$APP_DIR"
    if [ $OS = "$AIX" ]; then
        chgrp -R system $APP_DIR
    else
        chgrp -R root $APP_DIR
    fi
}

RemoveStartup() {
	if [ $OS = "$VIMA" -o $OS = "$XENSERVER" ]; then
    	if [ -f $STARTUP ]; then
        	if [ -n "$CHKCONFIG" ]; then
           		$CHKCONFIG PowerChute off
            	$CHKCONFIG --del PowerChute
        	else
            	rm -f /etc/rc.d/rc1.d/K99PowerChute
            	rm -f /etc/rc.d/rc2.d/S99PowerChute
            	rm -f /etc/rc.d/rc3.d/S99PowerChute
            	rm -f /etc/rc.d/rc4.d/S99PowerChute
            	rm -f /etc/rc.d/rc5.d/S99PowerChute
            	rm -f /etc/rc.d/rc6.d/K99PowerChute
        	fi
        	rm -f $STARTUP
    	fi
  	else
    	case "$OS" in
    		$LINUX)
    			if [ -n "$SYSTEMCTL" ]; then
    				$SYSTEMCTL disable PowerChute.service
    				rm -f /etc/systemd/system/PowerChute.service
    			else
    				if [ -n "$CHKCONFIG" ]; then
           				$CHKCONFIG PowerChute off
            			$CHKCONFIG --del PowerChute
        			else
            			rm -f /etc/rc.d/rc1.d/K99PowerChute
            			rm -f /etc/rc.d/rc2.d/S99PowerChute
            			rm -f /etc/rc.d/rc3.d/S99PowerChute
            			rm -f /etc/rc.d/rc4.d/S99PowerChute
            			rm -f /etc/rc.d/rc5.d/S99PowerChute
            			rm -f /etc/rc.d/rc6.d/K99PowerChute
        			fi
        			rm -f $STARTUP
    			fi
    			;;
    		$SOLARIS)
        		rm -f /etc/rc2.d/S99PowerChute
        		rm -f /etc/rc0.d/K99PowerChute
        		;;
    		$HPUX)
        		if [ -f /sbin/init.d/pcns ]; then
            		rm -f /sbin/rc1.d/K990pcns
            		rm -f /sbin/rc2.d/S990pcns
            		rm -f /sbin/init.d/pcns
        		fi
        		;;
    		$AIX)
        		if [ -f /etc/rc.APCpcns ]; then
            		rmitab PCNS
            		rm -f /etc/rc.APCpcns
        		fi
        	;;
    	esac
  	fi
}

CancelAll() {
    cd "$SRC_DIR"
    if [ -n "$INSTALL_DIR" ]; then
        if [ -d "$INSTALL_DIR/PowerChute" ]; then
             # Perform install rollback if update installation aborts due to some error and rollback to previous configuration 
        	RollBackInstall
        else
            rm -f "$INSTALL_DIR/$PCNS_TAR*"
        fi
    fi
    Echo ""
    Echo "Installation cancelled."
    Echo ""
    exit $1
}

RollBackInstall() {
	if [ $UPDATE_INSTALL = $TRUE ]; then
    	if [ -d "$INSTALL_DIR/PowerChute_update_backup" ]; then
    		echo "Performing Install Rollback"
            rm -rf "$INSTALL_DIR/PowerChute"
            mv "$INSTALL_DIR/PowerChute_update_backup/" "$INSTALL_DIR/PowerChute"
            Echo "Startup script=$STARTUP"
            $STARTUP start
      	else
            rm -rf "$INSTALL_DIR/PowerChute"
            RemoveStartup
      	fi
 	else
    	rm -rf "$INSTALL_DIR/PowerChute"
    	RemoveStartup
 	fi 
}

ConfigureFirewall(){

    echo "Configure Firewall"
    if [ -f /usr/sbin/esxcfg-firewall ]; then
        echo "Configuring esxcfg-firewall"
		/usr/sbin/esxcfg-firewall -o 80,tcp,out,"APC PowerChute Port 80"
        /usr/sbin/esxcfg-firewall -o 3052,tcp,out,"APC PowerChute Port 3052"
        /usr/sbin/esxcfg-firewall -o 3052,tcp,in,"APC PowerChute Port 3052"
        /usr/sbin/esxcfg-firewall -o 3052,udp,out,"APC PowerChute Port 3052"
        /usr/sbin/esxcfg-firewall -o 3052,udp,in,"APC PowerChute Port 3052"
        /usr/sbin/esxcfg-firewall -o 6547,tcp,in,"APC PowerChute Port 6547"
    else
       #Configure firewalld (if required)
       if [ -n "$SYSTEMCTL" ]; then
         $SYSTEMCTL is-enabled firewalld 1>/dev/null 2>/dev/null
         OUT=$?
       else
         OUT=1
       fi
	   
       if [ $OUT -eq 0 ]; then
          echo "Configuring firewalld"
	  echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>" > PCNS.xml
	  echo "<service>" >> PCNS.xml
  	  echo "<short>PCNS</short>" >> PCNS.xml
  	  echo "<description>PowerChute Network Shutdown</description>" >> PCNS.xml
  	  echo "<port protocol=\"tcp\" port=\"3052\"/>" >> PCNS.xml
  	  echo "<port protocol=\"tcp\" port=\"6547\"/>" >> PCNS.xml
  	  echo "<port protocol=\"udp\" port=\"3052\"/>" >> PCNS.xml
  	  echo "<port protocol=\"udp\" port=\"7778\"/>" >> PCNS.xml
	  echo "</service>" >> PCNS.xml

	  mv PCNS.xml /usr/lib/firewalld/services/pcns.xml
	  firewall-cmd --reload 1>/dev/null 2>/dev/null  
          firewall-cmd --add-service pcns --permanent 1>/dev/null 2>/dev/null
	  firewall-cmd --reload 1>/dev/null 2>/dev/null
       else
   
	  if [ $OS = $VIMA ] || [ $OS = $LINUX ]; then
	    service iptables status 1>/dev/null 2>/dev/null
	    OUT=$?
	  else 
	    OUT=0
	  fi

	  if [ $OUT -eq 0 ]; then
            echo "Configuring iptables"
            if [ -f /sbin/iptables ] || [ -f /usr/sbin/iptables ]; then
              iptables -I OUTPUT -p tcp --sport 80 -j ACCEPT
              iptables -I OUTPUT -p tcp --sport 3052 -j ACCEPT
              iptables -I INPUT -p tcp --dport 3052 -j ACCEPT
              iptables -I OUTPUT -p udp --sport 3052 -j ACCEPT
              iptables -I INPUT -p udp --dport 3052 -j ACCEPT
              iptables -I INPUT -p tcp --dport 6547 -j ACCEPT
              service iptables save
            fi
	
	    if [ -f /sbin/ip6tables ] || [ -f /usr/sbin/ip6tables ]; then
              ip6tables -I OUTPUT -p tcp --sport 80 -j ACCEPT
              ip6tables -I OUTPUT -p tcp --sport 3052 -j ACCEPT
              ip6tables -I INPUT -p tcp --dport 3052 -j ACCEPT
              ip6tables -I OUTPUT -p udp --sport 3052 -j ACCEPT
              ip6tables -I INPUT -p udp --dport 3052 -j ACCEPT
              ip6tables -I INPUT -p tcp --dport 6547 -j ACCEPT
              service ip6tables save
            fi
	  fi #iptables enabled
       fi #iptables
   fi #esxi
}

DisplayEULA(){
    
    # Default to english license
    EULA="apclicense.txt"

    Echo "$LANG" | grep -i 'ja_JP.utf-*8'
    if [ $? -eq 0 ]; then
       EULA="apclicense.txt.ja_UTF8"
    fi

    Echo "$LANG" | grep -i 'ja_JP.IBM-*943'
    if [ $? -eq 0 ]; then
       EULA="apclicense.txt.ja_ANSI"
    fi

    Echo "$LANG" | grep -i 'eucJP'
    if [ $? -eq 0 ]; then
        EULA="apclicense.txt.ja_EUC"
    fi 
    
    # Extract EULA
    cp $PCNS_ZIP backup.tar.gz
    gunzip $PCNS_ZIP
    tar -xof $PCNS_TAR > /dev/null 2>&1
        
    # Display EULA
    printf "\nPress any key to display End User License Agreement\n"
    Pause
    more "PowerChute/group1/$EULA"
    
    # Remove file, now that we've read it.
    rm -rf PowerChute > /dev/null 2>&1
    rm -rf $PCNS_TAR > /dev/null 2>&1
    mv backup.tar.gz $PCNS_ZIP > /dev/null 2>&1
    
    agreed=
    while [ -z "$agreed" ]
    do
        printf "\nDo you agree to the above license terms? [yes or no]\n"
        read reply leftover
        case $reply in
            [yY] | [yY][eE][sS])
                agreed=1
                ;;
            [nN] | [nN][oO])
                printf "If you don't agree to the license you can't install this software\n"
				printf "Aborting with error code-$EXIT_USER_ABORT\n"
                exit $EXIT_USER_ABORT
                ;;
            *)
                printf "Please enter \"yes\" or \"no\"."
                ;;
        esac
     done
}

AddESXiTargetServer() {

    if [ -f /etc/vima-release ] || [ -f /etc/vma-release ]; then
        echo " "
        echo "In order for PCNS to shutdown the ESXi host, it must be added as a target server."
        
        # validIP:
        # 0 - IP is valid
        # 1 - IP is invalid
        # 2 - User is skipping this
        
        validIP=1
                
        while [ $validIP -eq 1 ]
        do
            echo "Please enter ESXi host IP (XXX.XXX.XXX.XXX) or (q) to skip:"
            read esxihostip
        
            case $esxihostip in
                [qQ])
                    validIP=2
                    printf "\nSkipping configuration of ESXi Host Shutdown.\n"
                    ;;
            esac
            
            
            if [ $validIP -ne 2 ]; then
                # Validate IP
                valid_ip $esxihostip
                if [ $? -ne 0 ]; then
                    # invalid ip
                    printf "\nInvalid IP entered.\n"
                    validIP=1
                else
                    validIP=0
                fi                
            fi            
        done
        
        if [ $validIP -eq 0 ]; then
            echo "Please enter ESXi host username:"
            read esxihostuser
        
            echo "Please enter ESXi host password:"
            OLDCONFIG=`stty -g`
            stty -icanon -echo min 1 time 0
            read esxihostpwd
            stty $OLDCONFIG
        
            echo "Adding target server..."
            
            vifp addserver $esxihostip --username $esxihostuser --password $esxihostpwd
            vifp listservers | grep $esxihostip
            if [ $? -eq 0 ]; then
                    echo "Successfully added ESXi host to target server list."                    
                    echo ""
            else
                    echo "Failed to add ESXi host."
                    echo "To add the host manually please run - sudo vifp addserver <ipaddress>"
                    echo ""
            fi        
        fi        
    fi
}

valid_ip()
{
    ERROR=0
    oldIFS=$IFS
    IFS=.
    set -f
    set -- $1
    if [ $# -eq 4 ]; then
        for seg
        do
            case $seg in
                ""|*[!0-9]*) ERROR=1;break ;; ## Segment empty or non-numeric char
                *) [ $seg -gt 255 ] && ERROR=2 ;;
            esac
        done
    else
        ERROR=3 ## Not 4 segments
    fi
    IFS=$oldIFS
    set +f
    return $ERROR
}

CheckLocale(){
    Echo "$LANG" | grep -i 'ja*'
    if [ $? -eq 0 ]; then   
        # Abort, can't install english on Japanese OS.
        printf "\nThis version of PowerChute Network Shutdown does not support the Japanese language. Please consult www.apc.com for the required version of PowerChute Network Shutdown.\n"
		Echo "Aborting with error code-$EXIT_INVALID_LOCALE."
        exit $EXIT_INVALID_LOCALE
    fi    
}

ApplySilentConfig(){
    if [ "$SILENT_MODE" = "$TRUE" ]; then
        Echo "Applying Configuration ..."
        
        # Register with NMC
        oldDir=$PWD
        cd $APP_DIR/$GROUP1

        upgrade="false"
        if [ "$UPDATE_INSTALL" = "$TRUE" ]; then
            upgrade="true"
        fi                
        
        javaParams="-Xms32m -Xmx64m -Dfile.encoding=UTF-8 -cp .:comp/pcns.jar:lib/* -DsilentConfig=$SILENT_CONFIG -DsourceDir=\"$SRC_DIR\" -DapplicationDirectory=\"$APP_DIR\" -Dgroup=1 -Dupgrade=$upgrade --add-opens java.xml/com.sun.org.apache.xerces.internal.parsers=ALL-UNNAMED com.apcc.pcns.silentconfig.SilentConfig"
        echo ${JAVA_DIR}java  $javaParams 2>/dev/null > $APP_DIR/$GROUP1/run.sh
        chmod +x $APP_DIR/$GROUP1/run.sh
		$APP_DIR/$GROUP1/run.sh

        code=$?
		rm -f $APP_DIR/$GROUP1/run.sh
        if [ $code -ne 0 ]; then
            Echo "Error applying configuration.  Error code is: $code"
            CancelAll $code
        fi
        
        Echo "Configuration complete."
        cd $oldDir    
    fi
}

InstallHelp() {
    HELP_DIR="$INSTALL_DIR/PowerChute/group1/comp/http/html/Help"
    # Copy Standard Help files
    mv $HELP_DIR/Standard/* $HELP_DIR/. 1>/dev/null 2>/dev/null
    rmdir $HELP_DIR/Standard 1>/dev/null 2>/dev/null
}

InstallComplete(){
    NODE_NAME=`uname -n`
    Echo ""
    Echo "Installation has completed."
    Echo "PowerChute Network Shutdown can be accessed through your browser at https://<your_server_ip_address>:6547"

    if [ $UPDATE_INSTALL = $FALSE ]; then    
        Echo "Please complete the configuration wizard so that PowerChute Network Shutdown can protect your server."
    else
        Echo "Please run the configuration wizard so that PowerChute Network Shutdown can protect your server."
    fi
    
    Echo ""
}

######################################################################
# Main routine
######################################################################
SRC_DIR=`pwd`

# Check zipped install file
if [ ! -f $PCNS_ZIP ]; then
    Echo "Cannot find $PCNS_ZIP"
	Echo "Aborting with error code-$EXIT_ZIPFILE_MISSING."
    exit $EXIT_ZIPFILE_MISSING
fi

# Print Banner
Echo "------------------------------------------------------------------"
Echo "     PowerChute Network Shutdown 4.3.0 for Linux"
Echo "     Copyright (c) 1999-2018 Schneider Electric."
Echo "     All Rights Reserved."
Echo "------------------------------------------------------------------"
Echo ""

# Check OS type
CheckOS

# Check root account
IsRootUser

# Check Locale Compatibility
CheckLocale

checkForVMWare
checkForXenServer

# Check the OS architecture
CheckOSArch

# Initialize
Initialize

# Check silent install
if [ -z "$1" ]; then
    SILENT_MODE=$FALSE
elif [ "$1" = "-f" ]; then 
    if [ -r "$2" ]; then
        SILENT_MODE=$TRUE
        SILENT_CONFIG=$2
        Echo "Silent mode input from $SILENT_CONFIG"
        Echo ""
        SetSilentConfig
    else
	    Echo "Aborting with error code-$EXIT_SILENT_CONFIG_MISSING"
        Echo "Error: Invalid file $2"
        exit $EXIT_SILENT_CONFIG_MISSING
    fi
else
    PrintUsage
fi

# Show EULA
if [ $SILENT_MODE = $TRUE ]; then
   if [ "$ACCEPT_EULA" = "$STR_YES" ];  then
        Echo "EULA has been accepted"
   else
        Echo "Aborting with error code-$EXIT_EULA_NOT_ACCEPTED"
        Echo "Error: EULA must be accepted by setting ACCEPT_EULA=$STR_YES in config file"
        exit $EXIT_EULA_NOT_ACCEPTED
   fi
else
   DisplayEULA
fi

# Check installed applications
IsPCPlusInstalled
IsPCBEInstalled
IsPCSInstalled
IsPCNSInstalled

InitUpdate

# Set Install dir
SetInstallDir
BackupOldPCNS

APP_DIR="$INSTALL_DIR/PowerChute"

# Setup java
SetupJava

# Copy tar file to install dir
Echo "Copying the installation files ..."
cp "$PCNS_ZIP" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Extract PCNS files
Echo "Extracting PCNS files ..."
gunzip $PCNS_ZIP
tar -xf $PCNS_TAR > /dev/null 2>&1
if [ ! $? = 0 ]
then
    Echo "Failed to extract files"
fi
rm -rf $PCNS_TAR


cd "$APP_DIR"
Echo "PCNS is extracted to $APP_DIR"

# Setup script files
SetupAllCommandFiles

# Configure startup script
ConfigureAllStartup 
UninstallOldStartupLink
ConfigureStartupLink

if [ $UPDATE_INSTALL = $FALSE ]; then
   ConfigureFirewall
fi

# Configure uninstall script
ConfigureUninstall
ConfigureOwner

# For Update install
CopyUpdateFiles

#Install Help
InstallHelp

# Start the Service
SetupM11Cfg
ApplySilentConfig

# Delete the back up PowerChute folder once the update is done successfully.
UninstallOldPCNS

echo "Starting service ..."
if [ -n "$SYSTEMCTL" ]; then
	$SYSTEMCTL restart PowerChute
else 
	$SYSV_STARTUP start
fi

InstallComplete

cd "$SRC_DIR"
exit $EXIT_SUCCESS
