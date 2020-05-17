#!/bin/bash
#
#       Template file for scripts that are using choco-scripts framework
#

#
#   Path to the directory with this script
#
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

#
#   Path to the choco-scripts directory. By default it assumes the scripts 
#   are in the subdirectory 
#   You can change this path to your needs, but I suggest you to use '$THIS_DIR'
#   variable as it always contains absolute path to the directory of your script
#
CHOCO_SCRIPTS_DIR=$THIS_DIR/choco-scripts

#
#   Importing of the framework main script
#
source $CHOCO_SCRIPTS_DIR/functions.sh

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
