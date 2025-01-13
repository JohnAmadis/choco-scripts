#!/bin/bash
#
#       <SCRIPT_DESCRIPTION>
#

#
#   Path to the directory with this script
#
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


#
#   Path to the configuration file
#
CONFIGURATION_FILE_PATH=~/.choco-scripts.cfg
SCRIPT_DESCRIPTION=""

#
#   Verification of the choco scripts installation
#
if [ -f "$CONFIGURATION_FILE_PATH" ]
then 
    source $CONFIGURATION_FILE_PATH
else 
    printf "\033[31;1mChoco-Scripts are not installed for this user\033[0m\n"
    exit 1
fi

#
#   Information message
#
echo "Using choco-scripts from path $CHOCO_SCRIPTS_PATH in version $CHOCO_SCRIPTS_VERSION"

#
#   Importing of the framework main script
#
source $(getChocoScriptsPath)

#
#   The function prepares a framework script to work
#
function prepareScript()
{
    defineScript "$0" "<SCRIPT_DESCRIPTION>"
    
    <SCRIPT_ARGUMENTS>
    
    disableConfigurationPrinting
    parseCommandLineArguments "$@"
}

#######################################################################################
#
#   MAIN
#
prepareScript "$@"
