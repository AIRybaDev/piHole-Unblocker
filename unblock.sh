#!/bin/bash
# 
# Version 2.2
#
# Command line options:
# 
# -r | --rebuild
# Rebuild Gravity after updating whitelist
# 
# -p | --probe
# Only list affected domains without adding them to the whitelist
# 
# -l | --list
# Supresses all output except for affected domains. (For piping Output)
#
# -u | --update
# Download the latest version of this script from pastebin
#
# -y | --yes
# Adds the found subdomains to whitelist without confirmation.
# No effect when used with -p | --probe
# 
# The Tool-Internal Blacklist
# ----------------------------
#
# The internal blacklist of this tool allows filtering the found subdomains for specific, blacklisted words.
# Only subdomains that contain none of the words in this blacklist get whitelisted.
# The default blacklist consists of a regex for subdomains starting with "ad" or "ads".
# If -v is used, blacklists filtered out this way will be declared as such.
#
# -v | --verbose
# Print subdomains that were filtered out by internal blacklist to screen.
# Is ignored, if -l is used.
# 
# -f "/path/to/file.txt" | --file "/path/to/file.txt"
# Adds all lines within file.txt to the internal blacklist of this tool.
# 
# -b "some words to block" | --blacklist "some words to block"
# Adds these words to the blacklist of this tool.
# Can be used in conjunction with -f to expand the blacklist temporarily.
#  
 
pihole_path="/etc/pihole"
pihole_list="list.*"

update_url="https://pastebin.com/raw/EcweBtE9"
update_tempFile="/tmp/unblock_update.sh"
update_backup="/tmp/unblock_backup.sh"

filterRegex=""

cliNOPARAMS=0

cliREBUILD=0
cliLIST=0
cliPROBE=0
cliBLACKLIST=""
cliVERBOSE=0
cliYES=0
 
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
 
if [[ $# -eq 0 ]]; then
    echo "Please use one or more domains as arguments for this script:"
    echo "./"`basename "$0"`" example.com foo.org"
    exit 1
fi
 
while [[ $# > 0 ]]
do

	# Check for CLI switches
	if [ $cliNOPARAMS -ne 1 ]; then
		case $1 in
			-r|--rebuild)
				cliREBUILD=1
			;;
			-p|--probe)
				cliPROBE=1
			;;
			-l|--list)
				cliLIST=1
			;;
			-v|--verbose)
				cliVERBOSE=1
			;;
			-y|--yes)
				cliYES=1
			;;
			-b|--blacklist)
				blackListText=$2
				for line in $(echo "$blackListText"); do
					if [ "$line" != "" ]; then
						cliBLACKLIST="$cliBLACKLIST|($line)"
					fi
				done
				shift
			;;
			-f|--file)
				blackListFile=$2
				if [[ -f "$blackListFile" ]]; then
					while IFS=' ' read -r line; do
						if [ "$line" != "" ]; then
							cliBLACKLIST="$cliBLACKLIST|($line)"
						fi
					done < "$blackListFile"
				fi
				shift
			;;
			-u|--update)
				if [[ -f "$update_tempFile" ]]; then
					echo "Deleting last tempfile: $update_tempFile"
					rm -f "$update_tempFile"
				fi
				
				if [[ -f "$update_backup" ]]; then
					echo "Deleting last backup: $update_backup"
					rm -f "$update_backup"
				fi	
				
				if [[ ! -f "$update_tempFile" ]]; then
				
					if ! type "dos2unix" > /dev/null; then
						echo "dos2unix is required to update"
						sudo apt-get --yes install dos2unix
					fi
				
					echo "Downloading $update_url to $update_tempFile"
					wget -O "$update_tempFile" $update_url
					
					if [[ -f "$update_tempFile" ]]; then
					
						this_script=`realpath $0`
						echo "Download successful. Creating backup"
						cp "$this_script" "$update_backup"
						
						if [[ ! -f "$update_backup"  ]]; then
							echo "Failed creating a backup, aborting"
							exit
						fi

						echo "Backup successful, deleting old script"
						rm -f "$this_script"
						
						if [[ ! -f "$this_script" ]]; then
							
							echo "Deletion successful, installing new script"
							mv "$update_tempFile" "$this_script"
							
							if [[ -f "$this_script" ]]; then
								echo "Update successful"
								sudo chmod a+x "$this_script"
								sudo chown pi "$this_script"
								sudo dos2unix "$this_script"
							else
								echo "Update failed, restoring backup"
								cp "$update_backup" "$this_script"
								
								if [[ -f "$this_script" ]]; then
									echo "Backup restored successfully. Deleting backup"
									rm -f "$update_backup"
								else
									echo "Could not restore backup."
									echo "Please move $update_backup to $this_script manually"
								fi
							fi
						else 
							echo "Could not delete this script"
						fi
					else
						echo "Failed to download the update"
					fi
				else 
					echo "Could not delete the last tempfile"
				fi
				
				exit
			;;
			*)
				cliNOPARAMS=1
			;;
		esac
	fi

	if [ $cliNOPARAMS -eq 1 ]; then
	
		# Ordner wechseln
		if [ "$(pwd)" != "$pihole_path" ]; then
			if [ $cliLIST -ne 1 ]; then
					echo "Wechsel in Ordner $pihole_path"
			fi
			cd $pihole_path
			sudo chmod o+rw $pihole_list
		fi
	
		# Filter-Regex bauen
		if [ "$filterRegex" == "" ]; then
			filterRegex="((\bads?\b)"$cliBLACKLIST")"
			if [ $cliLIST -ne 1 ]; then
				echo "Filter-Regex $filterRegex"
			fi
		fi

		# Domain verarbeiten
		domain="$1"
		subdomains="$domain"
		if [ $cliLIST -ne 1 ]; then
			echo "--------------------------------------------------------------------------------------"
			echo "Looking for subdomains of $domain in blocklists"
		fi
	 
		for subdomain in $(grep --include list.\* -r -E -h "^([0-9a-z\-\_]+\.)*\b$domain(\.[a-z]{2,8})?$" | awk '!seen[$0]++' | sort -u); do
			if [ $(echo $subdomain | grep -cE "$filterRegex") -ne 0 ]; then
				if [ $cliLIST -ne 1 ]; then
					if [ $cliVERBOSE -eq 1 ]; then
						echo "Subdomain $subdomain is on Blacklist, skipping"
					fi
				fi
			else 
				if [ $cliLIST -ne 1 ]; then
					echo "Adding $subdomain to queue"
				else
					echo "$subdomain"
				fi
				subdomains="$subdomain $subdomains"
			fi
		done
	 
		if [ $cliPROBE -ne 1 ]; then
			addToWhitelist=0
			if [ $cliYES -eq 1 ]; then
				addToWhitelist=1
			else
				answerValid=0
				while [[ $answerValid -ne 1 ]]; do
					read -p "Add these domains to whitelist (y/n)?" choice
					case "$choice" in 
						y|Y )
							answerValid=1
							addToWhitelist=1
						;;
						n|N )
							answerValid=1
							addToWhitelist=0					
						;;
						* ) 
							echo "Invalid answer!"
							answerValid=0;
						;;
					esac
				done		
			fi
			
			if [ $addToWhitelist -eq 1 ]; then 
				if [ $cliLIST -ne 1 ]; then
					echo "Adding queue to whitelist"
				fi
				sudo pihole -w $subdomains
			fi
		fi
	fi

	shift 
done

if [ $cliREBUILD -ne 0 ]; then
	if [ $cliLIST -ne 1 ]; then
	echo "--------------------------------------------------------------------------------------"
		echo "Rebuilding gravity"
		sudo pihole -g
	fi
fi
 
exit