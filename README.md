# piHole Unblocker 

## What the program does

Since many blocklists piHole can use are suprisingly agressive in blocking content / sites
which a user might still want access, this program was created to not only whitelist that
domain, but also any subdomains associated with that domain that are currently blocked by
any of the installed blocklists.

Example:
Using this script to whitelist "*someDomain.tld*" would also whitelist "*mail.someDomain.tld*"
and "*ftp.someDomain.tld*" if these subdomains were included in any blocklists.

While this could also be accomplished by simply whitelisting that domain with a wildcard for
subdomains, such an approach would also whitelist domains that are most likely undesried by
all users, such as "*ads.someDomain.tld*". This is where this tool and most importantly its
internal blacklist comes into play:


## The Tool-Internal Blacklist

The internal blacklist of this tool allows filtering the found subdomains for specific, blacklisted words.
Only subdomains that contain none of the words in this blacklist get whitelisted.
The default blacklist consists of a regex for subdomains starting with "ad" or "ads".
Further words to blacklist can be provided with the `-f | --file` option, the `-b | --blacklist` option
or a combination of both options.
If `-v | --verbose` is used, blacklists filtered out this way will be declared as such.


## Why sudo?

This program needs sudo mainly to gain read-access on the folder containing the blocklists.
As new blocklists could have been installed with default permissions (owner root, chmod 640)
between the installation of this script and some use later, simply chmod-ing the existing
list files once on install won't do.


## Installation

For ease of use, it is recommended to append the following lines to your `.bash_aliases` file:
```
alias probe='sudo /path/to/unblock.sh -p -f /path/to/blacklist.txt'
alias unblock='sudo /path/to/unblock.sh -f /path/to/blacklist.txt'
```
This can also be achieved by running this script with the `--install` option.


## Usage
### Installation:   
```
git clone https://github.com/AIRybaDev/piHole-Unblocker unblocker
cd unblocker
./unblock.sh --install
```   
### Updating:   
 `./unblock.sh --update`  
### Unblocking: 
`sudo ./unblock.sh [options] <domain1> [<domain2> <domain3> ...]`

## Options
| Shorthand      | Long Version            | Parameter                      | Effect                                                                   | Interactions                                                             |
| -------------- | ----------------------- | ------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| `-r`           | `--rebuild`             | none                           | Rebuild Gravity after updating whitelist                                 |
| `-p`           | `--probe`               | none                           | Only list affected domains without adding them to the whitelist          |
| `-l`           | `--list`                | none                           | Supresses all output except for affected domains. (For piping Output)    | Activates `-p | --probe`                                                 |
| `-y`           | `--yes`                 | none                           | Adds the found subdomains to whitelist without confirmation              | No effect when used with `-p | --probe`                                  |
| `-v`           | `--verbose`             | none                           | Prints subdomains that were filtered out by internal blacklist to screen | Is ignored, if `-l | --list` is used                                     |
| `-f "<FILE>"`  | `--file "<FILE>"`       | Path to blacklist-file         | Adds all lines within `<FILE>` to the internal blacklist of this tool    |
| `-b "<WORDS>"` | `--blacklist "<WORDS>"` | Space-separated words to block | Adds these `<WORDS>` to the blacklist of this tool                       | Can be used in conjunction with `-f` to expand the blacklist temporarily |
| none           | `--install`             | none                           | Creates an alias for the script at its current location                  |
| `-u`           | `--update`              | none                           | Download the latest version of this script from GitHub                   |
| `-V`           | `--version`             | none                           | Show the version-number of this Script                                   |