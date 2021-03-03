#!/bin/bash

_script_version="2.4"
_script_location="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

function display_version(){
    echo "piHole Unlblocker - Version $_script_version"
}

function display_help(){
	cat <<-END

usage:
sudo unblock.sh [options] <domain1> [<domain2> <domain3> ...]
unblock.sh --install
unblock.sh --update


Options:
--------

-r | --rebuild
Rebuild Gravity after updating whitelist

-p | --probe
Only list affected domains without adding them to the whitelist

-l | --list
Supresses all output except for affected domains. (For piping Output)
Activates -p | --probe

-y | --yes
Adds the found subdomains to whitelist without confirmation.
No effect when used with -p | --probe

-v | --verbose
Print subdomains that were filtered out by internal blacklist to screen.
Is ignored, if -l is used.

-f "</path/to/file.txt>" | --file "</path/to/file.txt>"
Adds all lines within file.txt to the internal blacklist of this tool.

-b "<some words to block>" | --blacklist "<some words to block>"
Adds these words to the blacklist of this tool.
Can be used in conjunction with -f to expand the blacklist temporarily.

--install
Creates an alias for the script at its current location

-u | --update
Download the latest version of this script from GitHub

-V | --version
Show the version-number of this Script


What the program does:
----------------------

Since many blocklists piHole can use are suprisingly agressive in blocking content / sites
which a user might still want access, this program was created to not only whitelist that
domain, but also any subdomains associated with that domain that are currently blocked by
any of the installed blocklists.

Example:
Using this script to whitelist "someDomain.tld" would also whitelist "mail.someDomain.tld"
and "ftp.someDomain.tld" if these subdomains were included in any blocklists.

While this could also be accomplished by simply whitelisting that domain with a wildcard for
subdomains, such an approach would also whitelist domains that are most likely undesried by
all users, such as "ads.someDomain.tld". This is where this tool and most importantly its
internal blacklist comes into play:


The Tool-Internal Blacklist
----------------------------

The internal blacklist of this tool allows filtering the found subdomains for specific, blacklisted words.
Only subdomains that contain none of the words in this blacklist get whitelisted.
The default blacklist consists of a regex for subdomains starting with "ad" or "ads".
Further words to blacklist can be provided with the -f | --file option, the -b | --blacklist option
or a combination of both options.
If -v is used, blacklists filtered out this way will be declared as such.


Why sudo?
---------
This program needs sudo mainly to gain read-access on the folder containing the blocklists.
As new blocklists could have been installed with default permissions (owner root, chmod 640)
between the installation of this script and some use later, simply chmod-ing the existing
list files once on install won't do.


Installation
------------

For ease of use, it is recommended to append the following lines to your .bash_aliases file:
    alias probe='sudo $_script_location/unblock.sh -p -f $_script_location/blacklist.txt'
    alias unblock='sudo $_script_location/unblock.sh -f $_script_location/blacklist.txt'
This can also be achieved by running this script with the --install option.

END
}

function install(){
    alias_file="$HOME/.bash_aliases"
    bashrc_file="$HOME/.bashrc"
    
    # Creating Alias file
    if [ ! -f "$alias_file" ]; then
        echo "Could not find alias file, creating it now"
        touch "$alias_file"
    fi
    
    # Adding 'probe'
    if [ $(cat "$alias_file" | grep -c "alias probe=") -gt 0 ]; then
        echo "Alias 'probe' already exists, skipping"
    else
        echo "Creating 'probe' Alias"
        echo "alias probe='sudo $_script_location/unblock.sh -p -f $_script_location/blacklist.txt'" >> "$alias_file"
    fi
    
    # Adding 'unblock'
    if [ $(cat "$alias_file" | grep -c "alias unblock=") -gt 0 ]; then
        echo "Alias 'unblock' already exists, skipping"
    else
        echo "Creating 'unblock' Alias"
        echo "alias unblock='sudo $_script_location/unblock.sh -f $_script_location/blacklist.txt'" >> "$alias_file"
    fi
}

function update(){
    update_url="https://raw.githubusercontent.com/AIRybaDev/piHole-Unblocker/main/unblock.sh"
    update_tempFile="/tmp/unblock_update.sh"
    update_backup="/tmp/unblock_backup.sh"
    
    if [[ -f "$update_tempFile" ]]; then
        echo "Deleting last tempfile: $update_tempFile"
        rm -f "$update_tempFile"
    fi
    
    if [[ -f "$update_backup" ]]; then
        echo "Deleting last backup: $update_backup"
        rm -f "$update_backup"
    fi
    
    if [[ ! -f "$update_tempFile" ]]; then
        
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
                    chmod a+x "$this_script"
                    if type "dos2unix" > /dev/null; then
                        dos2unix "$this_script"
                    fi
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
}

function check_root(){
    if [[ $# -eq 0 ]]; then
        echo "Please use one or more domains as arguments for this script:"
        echo "./"`basename "$0"`" example.com foo.org"
        exit 1
    fi
}

pihole_path="/etc/pihole"
pihole_list="list.*"

filterRegex=""

cliNOPARAMS=0

cliREBUILD=0
cliLIST=0
cliPROBE=0
cliBLACKLIST=""
cliVERBOSE=0
cliYES=0

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
                cliPROBE=1
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
            --install)
                install
                exit
            ;;
            -u|--update)
                update
                exit
            ;;
            -V|--version)
                display_version
                exit
            ;;
            -h|--help)
                display_version
                echo "========================================"
                display_help
                exit
            ;;
            *)
                # We have found a argument that is not a known option, thus it must be a domain and we can begin the unblocking
                cliNOPARAMS=1
            ;;
        esac
    fi
    
    # The unblocking begins here, after all known options have been processed
    if [ $cliNOPARAMS -eq 1 ]; then
        
        check_root
        
        # Change the working directory
        if [ "$(pwd)" != "$pihole_path" ]; then
            if [ $cliLIST -ne 1 ]; then
                echo "Changing into folder $pihole_path"
            fi
            cd $pihole_path
            sudo chmod o+rw $pihole_list
        fi
        
        # Build regular expression for filtering
        if [ "$filterRegex" == "" ]; then
            filterRegex="((\bads?\b)"$cliBLACKLIST")"
            if [ $cliLIST -ne 1 ]; then
                echo "Filter-Regex $filterRegex"
            fi
        fi
        
        # Process passed domains
        domain="$1"
        subdomains="$domain"
        if [ $cliLIST -ne 1 ]; then
            echo "--------------------------------------------------------------------------------------"
            echo "Looking for subdomains of $domain in blocklists"
        fi
        
        # grep --include list.\*
        #   Read all the content from all files starting with "list."
        #
        # -r
        #   Do so recursively (in case later updates store lists in subfolders)
        #
        # -h
        #   Supress the filenames while reading files
        #
        # -E "^([0-9a-z\-\_]+\.)*\b$domain(\.[a-z]{2,8})?$"
        #   Filter for lines where this regular expression applies:
        #       ^:                  Marks the beginning of the line. Used to avoid false-positives
        #       ([0-9a-z\-\_]+\.)*: Any number of subdomains terminated with a period prepending the domain
        #       \b$domain:          The domain to be unblocked. "$domain" will be expanded before the regex is applied
        #       (\.[a-z]{2,8}):     A period, followed by the top-level-domain (tld), which is 2 to 8 characters long
        #       ?:                  Makes the tld optional in case the user has already submitted a tld in $domain
        #       $:                  Marks the end of the line. Used to avoid false-positives
        #
        # | awk '!seen[$0]++'
        #   Filters the found subdomains for uniqueness, so we don't unblock the same subdomain multiple times if it is in multiple lists
        #
        # | sort -u
        #   Sort found subdomains alphabetically (both for aesthetics and convenience)
        
        for subdomain in $(grep --include list.\* -r -h -E "^([0-9a-z\-\_]+\.)*\b$domain(\.[a-z]{2,8})?$" | awk '!seen[$0]++' | sort -u); do
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
                # This loop promts for an answer that is either y, yes, n or no
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