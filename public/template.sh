#!/bin/bash
#
#       Template file for scripts that are using choco-scripts framework
#

#
#   Path to the directory with this script
#
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

#
#   Path to the configuration file
#
CONFIGURATION_FILE_PATH=~/.choco-scripts.cfg

#
#   Verification of the choco scripts installation
#
if [ "$CHOCO_SCRIPTS_VERSION" == "" ] 
then 
    if [ -f "$CONFIGURATION_FILE_PATH" ]
    then 
        source $CONFIGURATION_FILE_PATH
    else 
        printf "\033[31;1mChoco-Scripts are not installed for this user\033[0m\n"
        exit 1
    fi
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
    defineScript "$0" "My hello-world script based on choco-scripts framework in version $(cat $CHOCO_SCRIPTS_DIR/version)"
    
    addCommandLineOptionalArgument EXAMPLE_ARGUMENT "-s|--string" "not_empty_string" "Example argument to be parsed from command line arguments" "This is my message from command line argument"
    
    parseCommandLineArguments "$@"
}

#######################################################################################
#
#   MAIN
#
prepareScript "$@"

echo $EXAMPLE_ARGUMENT
