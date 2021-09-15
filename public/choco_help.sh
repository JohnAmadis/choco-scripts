#!/bin/bash
#
#       Prints help for a choco-script functions
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


FUNCTIONS_FILE_NAME=functions.sh
FUNCTIONS_FILE_PATH=$CHOCO_SCRIPTS_PATH/$FUNCTIONS_FILE_NAME

#
#   Returns list of supported choco-script functions
#
function getListOfFunctions()
{
    local pattern="${1}"
    if isStringEmpty "$pattern"
    then 
        cat $FUNCTIONS_FILE_PATH | grep -E '^function\s+[^_]' | sed -E 's/^function\s+(\w+)\(\)/\1/g'
    else 
        cat $FUNCTIONS_FILE_PATH | grep -E '^function\s+[^_]' | grep -E "$pattern" | sed -E 's/^function\s+(\w+)\(\)/\1/g'
    fi
}

#
#   Returns list of function arguments 
#
function getListOfFunctionArguments()
{
    local functionName=$1
    
    cat $FUNCTIONS_FILE_PATH | grep -A 20 -E "^function\s+$functionName\(\)\$" | grep -E '\s+local\s+\w+=[\"]*\$[0-9]' | sed -E 's/\s+local\s+([^=]+).*$/\1/g'
}

#
#   Prints help for a given function argument
#
function getHelpForFunctionArgument()
{
    local functionName=$1
    local argumentName=$2
    
    cat $FUNCTIONS_FILE_PATH | grep -A 20 -E "^function\s+$functionName\(\)\$" | grep -B 1 -E "\s+local\s+$argumentName" | grep "#" | sed -E 's/^\s*\#\s*//g'
}

#
#   Prints help for a function arguments
#
function getHelpForFunctionArguments()
{
    local functionName=$1
    local functionArguments=$(getListOfFunctionArguments "$functionName")
    local argumentDescription=""
    if [ ${#functionArguments} -ne 0 ]
    then 
        for argument in ${functionArguments[*]}
        do 
            argumentDescription=$(getHelpForFunctionArgument "$functionName" "$argument")
            if isStringEmpty "$argumentDescription"
            then 
                argumentDescription="No description provided"
            fi
            printf "%-20s - %-50s\n" "$argument" "$argumentDescription"
        done 
    else 
        printf "The function does not take any argument" " "
    fi
}

#
#   Prints help for a function
#
function getHelForFunction()
{
    local functionName=$1
    local functionArguments=$(getListOfFunctionArguments "$functionName")
    
    cat $FUNCTIONS_FILE_PATH | grep -B 20 -E "^function\s+$functionName\(\)" | grep "#" | sed -E 's/\#//g'
}

export SUPPORTED_FUNCTIONS=$(getListOfFunctions)
SUPPORTED_FUNCTIONS=${SUPPORTED_FUNCTIONS/\n/ }

#
#   The function prepares a framework script to work
#
function prepareScript()
{
    defineScript "$0" "Prints help for a choco-script functions"
    
    addCommandLineOptionalArgument 'LIST' '--list' bool 'Prints list of supported choco-scripts functions' 'FALSE' ''
    addCommandLineOptionalArgument 'FUNCTION_NAME' '--function-name' options 'Name of the function to print a help for' 'None' "$(echo ${SUPPORTED_FUNCTIONS[*]}) None"
    addCommandLineOptionalArgument 'SEARCH_TEXT' '--search' string 'Regex pattern to search in a function names' '' 'get.*'
    
    parseCommandLineArguments "$@"
}

#
#   Prints a help for a given function
#
function printHelpOfFunction()
{   
    local functionName=$1
    local helpMessage=$(getHelForFunction "$functionName")
    local argumentsHelp=$(getHelpForFunctionArguments "$functionName")
    printf "\033[44;37;1m%5s%-80s\033[0m\n" " " "$functionName"
    echo "$helpMessage" | while read line 
    do
        printf "\033[45;37;1;3m%10s%-75s\033[0m\n" " " "$line"
    done
    printf "\033[45;37;1;3m%10s%-75s\033[0m\n" " " " "
    printf "\033[45;37;1;3m%10s%-75s\033[0m\n" " " "Function arguments:"
    printf "\033[45;37;1;3m%10s%-75s\033[0m\n" " " " "
    echo "$argumentsHelp" | while read line 
    do
        printf "\033[45;37;1;3m%15s%-70s\033[0m\n" " " "$line"
    done
    printf "\033[45;37;1;3m%10s%-75s\033[0m\n" " " " "
    printf "\n"
}

#
#   Prints list of supported functions
#
function printListOfFunctions()
{
    local pattern="$1"
    local function_names=$(getListOfFunctions "$pattern")
    for functionName in ${function_names[*]}
    do
        printHelpOfFunction "$functionName"
    done 
}

#######################################################################################
#
#   MAIN
#
prepareScript "$@"

if isStringEqual "$LIST" "TRUE"
then 
    printListOfFunctions
elif ! isStringEmpty "$SEARCH_TEXT"
then 
    printListOfFunctions "$SEARCH_TEXT"
elif ! isStringEqual "$FUNCTION_NAME" "None"
then
    printf "\n\n"
    printHelpOfFunction "$FUNCTION_NAME"
else 
    printHelp
fi
