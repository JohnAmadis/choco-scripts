#!/bin/bash
# Script for management of task flow

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SCRIPTS_DIR=$PROJECT_DIR

. $SCRIPTS_DIR/functions.sh

#
#   GLOBAL VARIABLES
#
export BITBUCKET_BASE_URL="https://api.bitbucket.org/2.0"
export BITBUCKET_USER_API="user"
export BITBUCKET_EMAIL_API="user/emails"
export ISSUE_DATA_FILE="$PROJECT_DIR/issue-data.json"
export ISSUE_DATA=""
export ISSUE_TITLE=""
export DEVELOP_BRANCH_NAME="develop"
export ISSUE_BRANCH_NAME=""
export USER_DATA=""
export USER_DATA_FILE="$PROJECT_DIR/user.json"
export USER_DISPLAYNAME=""
export EMAIL=""
export EMAIL_DATA=""
export EMAIL_DATA_FILE="$PROJECT_DIR/email.json"
export FULL_MESSAGE=""
export SUPPORTED_LANGUAGES=( "pl-PL" "en-US" "en-GB" )
export RELEASE_NOTES_MESSAGE=""

#
#   The function prepares a functions.sh script to work
#
function prepareScript()
{
    defineScript "$0" "The script is responsible for management of tasks flow"

    addCommandLineRequiredArgument ACTION "-a|--action" "options" "Action on task to perform. 'begin' starts work on new task by creating of a branch, stashing local changes and requesting issue data. If you select 'update', it will just update issue data from bitbucket. 'commit' just commits your changes." "begin update commit"
    addCommandLineRequiredArgumentWithDependencies BITBUCKET_USERNAME "-u|--user" "not_empty_string" "Username to use to login to the bitbucket server" "ACTION=begin ACTION=update" "johnsmith"
    addCommandLineOptionalArgument BITBUCKET_PASSWORD "-p|--password" "password" "Password for the user to use for logins in bitbucket server" ""
    addCommandLineRequiredArgumentWithDependencies ISSUE_ID "-i|--issue-id" "int" "ID of issue in bitbucket ChocoOrder repository" "ACTION=begin ACTION=update" "0"
    addCommandLineRequiredArgumentWithDependencies MESSAGE "-m|--message" "not_empty_string" "A message for the commit" "ACTION=commit" "message"
    addCommandLineOptionalArgument RELEASE_NOTES "--release" "bool" "If the flas is set, the script will ask for release notes and put it into the commit message" "FALSE"
    addCommandLineOptionalArgument COMMIT_ALL "--all" "bool" "Set this flag to true, if you want to commit all local changes. If it is set to false, you have to manually add changes before the script by calling 'git add'" "FALSE"
    addCommandLineOptionalArgument REPOSITORY_CONFIG_FILE "--config" "existing_file" "Path to a file with the repository configuration" "task-configuration.sh"
    
    addRequiredTool "docker" "Docker is a useful tool that allows for usage of 'containers' \n- a technology that at a first glance looks like virtual machines, but in fact it is an application \nthat simulates only the higher parts of the system. \nThanks to that you are able to use set of libraries, \ncommands and files without huge installation of full operating system, but you are able to \nprepare a stable environmental that works in the same way in all machines. If you will not install it, \nyou will be able to only run 'local' builds. If you will have the docker,\n the script will be able to pull the image and use it for \nthe builds of targets - you will not have to do anything more." "FALSE" "sudo apt-get install docker-ce -y"
    addRequiredTool "git" "GIT is a versioning control system. It is mandatory for the script" "TRUE" "sudo apt-get install git -y"
    addRequiredTool "jq" "It is a simple tool required for parsing JSON responses from bitbucket" "TRUE" "sudo apt-get install jq -y"
    
    parseCommandLineArguments "$@"
}

#
#   Sends request for issue data
#
function requestIssueData()
{
    USER_STRING="$BITBUCKET_USERNAME"
    if ! isStringEmpty "$BITBUCKET_PASSWORD"
    then 
        USER_STRING="$BITBUCKET_USERNAME:$BITBUCKET_PASSWORD"
    fi
    
    printInfo "Requesting issue data (ID #$ISSUE_ID)...\n"
    ISSUE_DATA=$(curl -X GET -u "$USER_STRING" -s "$BITBUCKET_BASE_URL/repositories/$PROJECT_NAME/$REPOSITORY_NAME/issues/$ISSUE_ID" )
    if isStringEmpty "$ISSUE_DATA"
    then 
        printError "Cannot read issue data!"
    fi
    
    printInfo "Saving issue data to: $ISSUE_DATA_FILE\n"
    echo "$ISSUE_DATA" > $ISSUE_DATA_FILE 
}

#
#   Sends request for user data
#
function requestUserData()
{
    USER_STRING="$BITBUCKET_USERNAME"
    if ! isStringEmpty "$BITBUCKET_PASSWORD"
    then 
        USER_STRING="$BITBUCKET_USERNAME:$BITBUCKET_PASSWORD"
    fi
    printInfo "Requesting user data (ID $BITBUCKET_USERNAME)...\n"
    USER_DATA=$(curl -X GET -u "$USER_STRING" -s "$BITBUCKET_BASE_URL/$BITBUCKET_USER_API" )
    if isStringEmpty "$USER_DATA"
    then 
        printError "Cannot read user data!"
    fi
    
    printInfo "Saving user data to: $USER_DATA_FILE\n"
    echo "$USER_DATA" > $USER_DATA_FILE
    
    printInfo "Requesting user email ...\n"
    EMAIL_DATA=$(curl -X GET -u "$USER_STRING" -s "$BITBUCKET_BASE_URL/$BITBUCKET_EMAIL_API" )
    if isStringEmpty "$EMAIL_DATA"
    then 
        printError "Cannot read email data!"
    fi
    printInfo "Saving email data to file $EMAIL_DATA_FILE\n"
    echo "$EMAIL_DATA" > $EMAIL_DATA_FILE
}

#
#   Assigns an issue to the current user 
#
function assignIssueToMe()
{
    USER_STRING="$BITBUCKET_USERNAME"
    if ! isStringEmpty "$BITBUCKET_PASSWORD"
    then 
        USER_STRING="$BITBUCKET_USERNAME:$BITBUCKET_PASSWORD"
    fi
    printInfo "Assigning the issue $ISSUE_TITLE to user $BITBUCKET_USERNAME\n"
    if doCommand curl -X PUT -H "'Content-Type: application/json'" -u "$USER_STRING" -s "$BITBUCKET_BASE_URL/repositories/$PROJECT_NAME/$REPOSITORY_NAME/issues/$ISSUE_ID" -d "'{ \"assignee\" : { \"username\": \"$BITBUCKET_USERNAME\" } }'"
    then 
        printInfo "Issue '$ISSUE_ID' has been assigned to the user '$BITBUCKET_USERNAME'\n"
    else 
        printError "Cannot assign issue $ISSUE_ID to the user '$BITBUCKET_USERNAME'"
    fi
}

#
#   Reads issue data from file
#
function readIssueDataFromFile()
{
    printInfo "Reading issue data from file $ISSUE_DATA_FILE\n"
    ISSUE_DATA=$(cat $ISSUE_DATA_FILE)
    if isStringEmpty "$ISSUE_DATA"
    then 
        printError "Cannot read issue data from file $ISSUE_DATA_FILE!"
    fi
}

#
#   Reads user data from file
#
function readUserDataFromFile()
{
    printInfo "Reading user data from file $USER_DATA_FILE\n"
    USER_DATA=$(cat $USER_DATA_FILE)
    if isStringEmpty "$USER_DATA"
    then 
        printError "Cannot read user data from file $USER_DATA_FILE!"
    fi
    EMAIL_DATA=$(cat $EMAIL_DATA_FILE)
    if isStringEmpty "$EMAIL_DATA"
    then 
        printError "Cannot read email from file $EMAIL_DATA_FILE"
    fi
}

#
#   Reads information about the issue from bitbucket 
#
function readIssueData()
{
    ISSUE_ID=$(readFromJson "$ISSUE_DATA" "id")
    ISSUE_TITLE=$(readFromJson "$ISSUE_DATA" "title" )
    ISSUE_BRANCH_NAME="$(createGitBranchName "feature/$ISSUE_ID-$ISSUE_TITLE")"
    printInfo "Issue data has been read.\n"
    printInfo "----------------------------------------------------------------------------------------------------------------------------\n"
    printInfo "       ID: $ISSUE_ID\n"
    printInfo "       Title: '$ISSUE_TITLE'\n"
    printInfo "       Branch-name: $ISSUE_BRANCH_NAME\n"
    printInfo "----------------------------------------------------------------------------------------------------------------------------\n"
}

#
#   Reads information about the user
#
function readUserData()
{
    USER_DISPLAYNAME=$(readFromJson "$USER_DATA" "display_name")
    EMAIL=$(readFromJson "$EMAIL_DATA" "values[0].email")
    printInfo "User data has been read.\n"
    printInfo "----------------------------------------------------------------------------------------------------------------------------\n"
    printInfo "      Display-name: $USER_DISPLAYNAME\n"
    printInfo "      Email: $EMAIL\n"
    printInfo "----------------------------------------------------------------------------------------------------------------------------\n"
}

#
#   Prepares full commit message
#
function prepareFullCommitMessage()
{
    FULL_MESSAGE=$(cat<<LOG
#$ISSUE_ID - $ISSUE_TITLE

reopen #$ISSUE_ID
                  
Changes:
                  
    - $MESSAGE
                  
Signed-by:
    $USER_DISPLAYNAME <$EMAIL>
                  
$RELEASE_NOTES_MESSAGE
LOG
)
}

#
#   Requests user for release notes
#
function requestForReleaseNotes()
{
    RELEASE_NOTES_MESSAGE="Release notes: \n\n"
    for language in ${SUPPORTED_LANGUAGES[*]}
    do
        if printQuestionWithStringAnswer "Please provide release note for language '$language'" RESPONSE
        then 
            RELEASE_NOTES_MESSAGE="$RELEASE_NOTES_MESSAGE\t\t -[RELEASE-NOTE:$language]: $RESPONSE\n"
        else 
            printError "Operation has been canceled"
        fi
    done
}

#
#   Performs action 'begin'
#
function performActionBegin()
{
    requestIssueData
    requestUserData
    readIssueData
    readUserData
    assignIssueToMe
    switchGitBranch "$DEVELOP_BRANCH_NAME"
    createGitBranch "$ISSUE_BRANCH_NAME"
}

#
#   Performs action 'update'
#
function performActionUpdate()
{
    requestIssueData
    requestUserData
}

#
#   Performs action 'commit'
#
function performActionCommit()
{
    readIssueDataFromFile
    readUserDataFromFile
    readIssueData
    readUserData
    if isStringEqual "$RELEASE_NOTES" "TRUE"
    then 
        requestForReleaseNotes
    fi
    prepareFullCommitMessage
    
    if isStringEqual "$COMMIT_ALL" "TRUE"
    then 
        gitCommitAll "$FULL_MESSAGE"
    else
        gitCommit "$FULL_MESSAGE"
    fi
}

#
#   Reads configuration file
#
function readConfiguration()
{
    printInfo "Reading configuration from $REPOSITORY_CONFIG_FILE\n"
    source $REPOSITORY_CONFIG_FILE
    
    if isStringEmpty "$PROJECT_NAME"
    then 
        printError "Configuration file is not valid - 'PROJECT_NAME' variable is not set"
    elif isStringEmpty "$REPOSITORY_NAME"
    then 
        printError "Configuration file is not valid - 'REPOSITORY_NAME' variable is not set"
    fi
}

#
#   Performs action
#
function performAction()
{
    printInfo "Performing action '$ACTION'\n"
    if isStringEqual "$ACTION" "begin"
    then 
        performActionBegin
    elif isStringEqual "$ACTION" "update"
    then 
        performActionUpdate
    elif isStringEqual "$ACTION" "commit"
    then
        performActionCommit
    else
        printError "Unknown action: $ACTION"
    fi
}

#
#   Main
#
prepareScript "$@"
readConfiguration
performAction
