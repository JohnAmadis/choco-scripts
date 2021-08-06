#!/bin/bash
#
#       Creates a new script based on the choco-scripts framework
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

#######################################################################################
#
#   GLOBAL VARIABLES
#
ARGUMENTS=""

#######################################################################################
#
#   FUNCTIONS
#

#
#   The function prepares a framework script to work
#
function prepareScript()
{
    defineScript "$0" "The script is designed for creation of a new script based on the choco-script framework."
    
    addCommandLineOptionalArgument PRINT_SUPPORTED_ARGUMENT_TYPES --print-supported-arguments bool 'If the flag is set, the script prints all the supported argument types' 'FALSE'
    
    parseCommandLineArguments "$@"
}

#
#   The function prints all the supported argument types
#
function printSupportedArgumentTypes()
{
    local supported_argument_types=$(getSupportedArgumentTypes)
    local description
    printf "\n\033[36;1mHere is the list of supported argument types: \n\n\033[0m"
    
    for type in ${supported_argument_types[*]}
    do
        description=$(addIndentationToStringOnNewLine "$(getArgumentTypeDescription $type)" "\t\t\t\t\t")
        printf "\t\t\033[34;1m$type\033[0m\n\033[37;1m$description\033[0m\n\n"
    done 
}

#
#   Requests for a name for the script
#
function requestScriptPath()
{
    if ! printQuestionWithStringAnswer "Where do you want to create your script? Please provide a destination directory path." TARGET_DIRECTORY_PATH "$(pwd)"
    then 
        exit 1
    fi
}

#
#   Requests for a name for the script
#
function requestScriptName()
{
    if ! printQuestionWithStringAnswer "What should be a file name for your script?" SCRIPT_FILE_NAME
    then 
        exit 1
    fi
    SCRIPT_FILE_PATH="$TARGET_DIRECTORY_PATH/$SCRIPT_FILE_NAME"
}

#
#   Creates a script based on the template
#
function createScript()
{
    copyFile "$(getChocoTemplatePath)" "$SCRIPT_FILE_PATH"
}

#
#   Requests for a script description
#
function requestScriptDescription()
{
    if ! printQuestionWithStringAnswer "Please provide a short description of the script" SCRIPT_DESCRIPTION
    then 
        exit 1
    fi
    
    sed -r "s/<SCRIPT_DESCRIPTION>/$SCRIPT_DESCRIPTION/g" -i "$SCRIPT_FILE_PATH"
}

#
#   Requests argument name 
#
function requestArgumentName()
{
    local variableName=$1
    if ! printQuestionWithStringAnswer "What should be the argument name?" $variableName
    then 
        exit 1
    fi
}

#
#   Requests user about the argument type
#
function requestArgumentType()
{
    local variableName=$1
    local argumentName=$2
    if ! printQuestionWithEnumAnswer "What should be the argument type for argument '$argumentName'? " $variableName "$(getSupportedArgumentTypes)" "bool"
    then 
        exit 1
    fi
}

#
#   Requests user about the argument description
#
function requestArgumentDescription()
{
    local variableName=$1
    local argumentName=$2
    if ! printQuestionWithStringAnswer "What should be the description for argument '$argumentName'? " $variableName  
    then 
        exit 1
    fi
}

#
#   Requests user about the argument options
#
function requestArgumentOptions()
{
    local variableName=$1
    local argumentName=$2
    if ! printQuestionWithStringAnswer "What are possible options for argument '$argumentName'? (values should be separated by a space)" $variableName  
    then 
        exit 1
    fi
}

#
#   Requests user about the regex for argument 
#
function requestArgumentRegex()
{
    local variableName=$1
    local argumentName=$2
    if ! printQuestionWithStringAnswer "What should be a regular expression used for validation of the argument '$argumentName'?" $variableName  
    then 
        exit 1
    fi
}

#
#   Checks if the argument value is valid
#
function isArgumentValueValid()
{
    validateArgumentValue "$argumentVariableName" "$1" "FALSE"
}

#
#   Requests for a default value of the argument
#
function requestDefaultArgumentValue()
{
    local variableName=$1
    local argumentName=$2
    local argumentType=$3
    local argumentVariableName=$4
    local defaultValue=""
    setArgumentType "$argumentVariableName" "$argumentType"
    if isStringEqual "$argumentType" "options"
    then 
        local argumentOptions="$5"
        if ! printQuestionWithEnumAnswer "What should be a default value for the argument '$argumentName'?" $variableName "${argumentOptions[*]}"
        then 
            exit 1
        fi
    else 
        if isStringEqual "$argumentType" "bool"
        then 
            defaultValue="FALSE"
        elif isStringEqual "$argumentType" "regex"
        then 
            local regularExpression="$5"
            setArgumentRegularExpression "$argumentVariableName" "$regularExpression"
        fi
        if ! printQuestionWithValidator "What should be a default value for the argument '$argumentName'? " $variableName isArgumentValueValid "$defaultValue"
        then 
            exit 1
        fi
    fi
}

#
#   Requests for an example value of the argument
#
function requestExampleArgumentValue()
{
    local variableName=$1
    local argumentName=$2
    local argumentType=$3
    local argumentVariableName=$4
    local defaultValue=""
    setArgumentType "$argumentVariableName" "$argumentType"
    if isStringEqual "$argumentType" "options"
    then 
        local argumentOptions="$5"
        if ! printQuestionWithEnumAnswer "What should be an example value for the argument '$argumentName'?" $variableName "${argumentOptions[*]}"
        then 
            exit 1
        fi
    else 
        if isStringEqual "$argumentType" "bool"
        then 
            defaultValue="FALSE"
        elif isStringEqual "$argumentType" "regex"
        then 
            local regularExpression="$5"
            setArgumentRegularExpression "$argumentVariableName" "$regularExpression"
        fi
        if ! printQuestionWithValidator "What should be an example value for the argument '$argumentName'? " $variableName isArgumentValueValid "$defaultValue"
        then 
            exit 1
        fi
    fi
}

#
#   Requests argument informations
#
function requestArgumentInfo()
{
    local argumentName=""
    local argumentType=""
    local argumentDescription=""
    local variableName=""
    local scriptArgumentName=""
    local argumentMandatory=""
    local argumentOptions=""
    local argumentRegex=""
    local defaultArgumentValue=""
    local exampleArgumentValue=""
    
    requestArgumentName argumentName
    variableName=$(toVariableName "$argumentName")
    scriptArgumentName=$(toScriptArgument "$argumentName")
    if ! isKnownArgument "$variableName"
    then 
        addArgument "$variableName" "optional"
    else 
        printError "The argument $variableName already exists!" "FALSE"
        return 1
    fi
    
    requestArgumentType argumentType "$argumentName"
    if isStringEqual "$argumentType" "options"
    then 
        requestArgumentOptions argumentOptions "$argumentName"
        requestExampleArgumentValue exampleArgumentValue "$argumentName" "$argumentType" "$variableName" "$argumentOptions"
    elif isStringEqual "$argumentType" "regex"
    then 
        requestArgumentRegex argumentRegex "$argumentName"
        requestExampleArgumentValue exampleArgumentValue "$argumentName" "$argumentType" "$variableName" "$argumentRegex"
    fi
    if printQuestion "Should the argument '$argumentName' be mandatory?"
    then 
        argumentMandatory=0
    else 
        argumentMandatory=1
        requestDefaultArgumentValue defaultArgumentValue "$argumentName" "$argumentType" "$variableName" "$argumentOptions$argumentRegex"
    fi
    requestArgumentDescription argumentDescription "$argumentName"
    echo "variable name: $variableName"
    echo "script argument name: $scriptArgumentName"
    echo "argument type: $argumentType"
    
    if [ $argumentMandatory -eq 0 ]
    then 
        ARGUMENTS="${ARGUMENTS}    addCommandLineRequiredArgument '$variableName' '$scriptArgumentName' $argumentType '$argumentDescription' '$argumentRegex$argumentOptions'\n"
    else 
        ARGUMENTS="$ARGUMENTS    addCommandLineOptionalArgument '$variableName' '$scriptArgumentName' $argumentType '$argumentDescription' '$defaultArgumentValue' '$argumentRegex$argumentOptions'\n"
    fi
}

#
#   The function shows a requests to get a script parameters from a user
#
function requestScriptParameters()
{
    printf "\nWelcome to the \033[37;1mChoco-Scripts\033[0m generator. The configurator will ask you few questions about the script you want to create\n\n"
    requestScriptPath
    requestScriptName
    createScript
    requestScriptDescription
    
    while printQuestion "Do you want to add a new argument to the script?"
    do
        requestArgumentInfo
    done
    
    sed "s/    <SCRIPT_ARGUMENTS>/$ARGUMENTS/g" -i "$SCRIPT_FILE_PATH"
}

#######################################################################################
#
#   MAIN
#
prepareScript "$@"

if isStringEqual "$PRINT_SUPPORTED_ARGUMENT_TYPES" "TRUE"
then 
    printSupportedArgumentTypes
else 
    requestScriptParameters
fi
