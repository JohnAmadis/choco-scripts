#!/bin/bash

declare -a __ARGUMENTS
declare -a __REQUIRED_ARGUMENTS
declare -A __ARGUMENT_LONG_NAMES
declare -A __ARGUMENT_SHORT_NAMES
declare -A __ARGUMENT_TYPES
declare -A __ARGUMENT_DESCRIPTIONS
declare -A __ARGUMENT_SUPPORTED_VALUES
declare -A __ARGUMENT_DEFAULT_VALUES
declare -A __ARGUMENT_EXAMPLE_VALUES
declare -A __ARGUMENT_TYPE_DESCRIPTIONS
declare -A __ARGUMENT_TYPE_EXAMPLES
declare -A __ARGUMENT_REGULAR_EXPRESSIONS
declare -a __SUPPORTED_ARGUMENT_TYPES
declare -A __ARGUMENT_VALUE_SET
declare -A __ARGUMENT_DEPENDENCIES
declare -A __REQUIRED_TOOLS_DESCRIPTIONS
declare -a __REQUIRED_TOOLS
declare -a __REQUIRED_TOOLS_MANDATORY
declare -A __REQUIRED_TOOLS_INSTALLATION_COMMAND

__SCRIPT_NAME=""
__SCRIPT_DESCRIPTION=""

#
#   Encrypts a password to the bcrypt code
#
function getPasswordBcryptEncrypted()
{
    local PASSWORD=$1
    setToolMandatory "php" 
    php -r "print_r(password_hash('$PASSWORD', PASSWORD_BCRYPT));"
}

#
#   Joins array by delimiter
#
function joinBy 
{ 
    local IFS="$1"; 
    shift; 
    echo "$*"; 
}

#
#   Checks if the current user is root 
#
function isRoot()
{
    if [[ $EUID -ne 0 ]] 
    then
        return 1
    else 
        return 0
    fi
}

#
#   Returns size of file
#
function getFileSize()
{
    local FILE_PATH=$1
    FILE_SIZE_B=$(stat -c%s "$FILE_PATH")
    let FILE_SIZE_kB=$FILE_SIZE_B/1024
    let FILE_SIZE_MB=$FILE_SIZE_kB/1024
    let FILE_SIZE_GB=$FILE_SIZE_MB/1024
    let FILE_SIZE_TB=$FILE_SIZE_GB/1024
    if [ $FILE_SIZE_TB -gt 0 ];
    then    
        echo "$FILE_SIZE_TB TB"
    elif [ $FILE_SIZE_GB -gt 0 ];
    then 
        echo "$FILE_SIZE_GB GB"
    elif [ $FILE_SIZE_MB -gt 0 ];
    then 
        echo "$FILE_SIZE_MB MB"
    elif [ $FILE_SIZE_kB -gt 0 ];
    then 
        echo "$FILE_SIZE_MB kB"
    else 
        echo "$FILE_SIZE_B Bytes"
    fi
}

#
#   Returns MAC address of the given interface 
#
function getMac()
{
    local ifname=$1
    ifconfig $ifname 2>&1 | grep HWaddr | sed 's/.*HWaddr \(.*\)$/\1/g' 
    ifconfig eth0 2>&1 | grep ether | sed 's/.*ether \([a-z0-9\:]*\).*$/\1/g'
}

#
#   Checks if verbose mode is enabled
#
function isVerboseMode()
{
    if isStringEqual "$VERBOSE" "TRUE"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Pulls the given file with wget
#
#       URL                 url to get a file from
#       OUTPUT_FILE         destination for the file
#       PULL_MODE           One of the following modes: force, ask, never
#                                   
#                                   force - file will be always pulled 
#                                   ask   - if file exists, the script will ask if it should be pulled 
#                                   never - dont pull a file if it exists
#
function pullFile()
{
    local URL="$1"
    local OUTPUT_FILE="$2"
    local PULL_MODE="$3"

    if fileExists "$OUTPUT_FILE" && ! isStringEqual "$PULL_MODE" "force"
    then 
        FILE_SIZE=$(getFileSize "$OUTPUT_FILE")
        if isStringEqual "$PULL_MODE" "never" 
        then 
            return 0
        elif isStringEqual "$PULL_MODE" "ask" && ! printQuestion "The file '$OUTPUT_FILE' already exists (File size: $FILE_SIZE). Do you want to pull it anyway?"
        then 
            return 0
        fi
    fi
    local DIR_PATH=$(dirname "$OUTPUT_FILE")
    setToolMandatory "wget"
    createDirectory "$DIR_PATH"
    doCommandAsStepWithSpinner "Pulling file from '$URL' to '$OUTPUT_FILE'" wget -O "$OUTPUT_FILE" "$URL"
    return $?
}

#
#   Checks if the given device is available
#
function isDeviceAvailable()
{
    local DEVICE_PATH="$1"
    if [ -f "$DEVICE_PATH" ]; 
    then 
        return 0
    elif $(sudo ls "$DEVICE_PATH" 2>&1 > /dev/null)
    then 
        return 0
    else
        return 1
    fi
}

#
#   Writes a given image to the device
#
function writeImageToDevice()
{
    local IMAGE_PATH="$1"
    local DEVICE_PATH="$2"
    
    if ! isDeviceAvailable "$DEVICE_PATH"
    then 
        printError "Device '$DEVICE_PATH' is not available!"
    fi
    
    if ! fileExists "$IMAGE_PATH"
    then 
        printError "Cannot find image file: '$IMAGE_PATH'"
    fi
    
    if ! printQuestion "The script is going to override a device '$DEVICE_PATH' - ALL DATA ON THE DEVICE WILL BE LOST! Do you want to continue?"
    then 
        printError "Stopped by a user"
    fi
    
    if isMounted "$DEVICE_PATH"
    then 
    
        for PARTITION in $(getPartitionsInDevice "$DEVICE_PATH")
        do
            if [ "$PARTITION" = "${LOOP_DEVICE_PATH}p*" ]; 
            then 
                PARTITION="$DEVICE_PATH"
            fi
            doCommandAsStep "Unmounting of device '$PARTITION'" sudo umount "$PARTITION"
        done
    fi
    FILE_SIZE=$(getFileSize "$IMAGE_PATH")
    doCommandAsStepWithSpinner "Writing of image '$IMAGE_PATH' (size: $FILE_SIZE) to the device '$DEVICE_PATH'" sudo dd "if=$IMAGE_PATH" "of=$DEVICE_PATH"
    return $?
}

#
#   Checks if path is writable 
#
function isPathWritable()
{
    local PATH="$1"
    if [ -w $PATH ]
    then 
        return 0
    else
        return 1
    fi
}

#
#   Converts integer to binary form
#
function toBinary()
{
    local VALUE=$1
    echo "obase=2;$VALUE" | bc
}

#
#   Returns file permissions
#
function getFilePermissions()
{
    local FILE_PATH="$1"
    stat -c %a "$FILE_PATH"
}

#
#   Mounting of device to the given path
#
function mountDevice()
{
    local DEVICE_PATH="$1"
    local MOUNT_PATH="$2"
    
    if ! isDeviceAvailable "$DEVICE_PATH"
    then 
        printError "Device '$DEVICE_PATH' is not available!"
    fi
    
    if ! createDirectory "$MOUNT_PATH"
    then 
        printError "Cannot create directory '$MOUNT_PATH'"
    fi
    
    doCommandAsStep "Mounting of device '$DEVICE_PATH' to path '$MOUNT_PATH'" sudo mount "$DEVICE_PATH" "$MOUNT_PATH"
    return $?
}

#
#   Creates new loop device for the image
#
function createLoopDeviceForImage()
{
    local IMAGE_PATH="$1"
    
    if ! fileExists "$IMAGE_PATH"
    then 
        printError "Cannot create loop device for image: '$IMAGE_PATH' - it does not exist!"
    fi
    
    doCommandAsStep "Creating new loop device" sudo losetup --show -f -P "$IMAGE_PATH"
}

#
#   Returns a loop device name for the given image file
#
function getLoopDeviceForImage()
{
    local IMAGE_PATH="$1"
    local DEVICES=$(losetup -j "$IMAGE_PATH" -O NAME -n)
    
    read DEVICE <<< "$DEVICES"
    
    if isStringEmpty "$DEVICE"
    then 
        DEVICE=$(sudo losetup --show -f -P "$IMAGE_PATH")
    fi
    
    if ! isStringEmpty "$DEVICE"
    then 
        echo "$DEVICE"
        return 0
    else
        return 1
    fi
}

#
#   Removes loop device of the given image
#
function removeLoopDeviceForImage()
{
    local IMAGE_PATH=$1
    local DEVICE=$(getLoopDeviceForImage "$IMAGE_PATH")
    
    if isStringEmpty "$DEVICE"
    then
        printInfo "Skipping removing of loop device for '$IMAGE_PATH' - cannot find related device\n"
        return 0
    fi
    
    doCommandAsStep "Removing of loop device '$DEVICE'" sudo losetup -d "$DEVICE"
}

#
#   Returns partitions in the given device
#
function getPartitionsInDevice()
{
    local DEVICE="$1"
    
    for PARTITION in "$DEVICE"?*; 
    do
        echo "$PARTITION"
    done
}

#
#   Reads partition label
#
function getPartitionLabel()
{
    local PARTITION=$1
    
    VALUES=$(sudo blkid -o value "$PARTITION")
    
    read LABEL <<< "$VALUES"
    echo "$LABEL"
}

#
#   Checks if the given device is mounted on the given path
#
function isMountedOn()
{
    local DEVICE_PATH="$1"
    local MOUNT_PATH="$2"
    
    mount | grep "$DEVICE_PATH on $MOUNT_PATH "
    return $?
}

#
#   Checks if the device is mounted
#
function isMounted()
{   
    local DEVICE_PATH="$1"
    mount | grep "$DEVICE_PATH"
    return $?
}

#
#   Waits for unmounting 
#
function waitForUnmount()
{
    local P=$1
    
    busy=true
    while $busy
    do
        if mountpoint-q "$P"
        then 
            sudo umount "$P" 2>/dev/null
            if [ $? -eq 0 ]
            then 
                busy=false
            else 
                sleep 5
            fi
        else 
            busy=false
        fi
    done
}

#
#   Mounts an image at the given path
#
function mountImage()
{
    local IMAGE_PATH=$1
    local MOUNT_PATH=$2
    
    if ! fileExists "$IMAGE_PATH"
    then 
        printError "Cannot mount image '$IMAGE_PATH' - it does not exist!"
    fi
    
    if ! createDirectory "$MOUNT_PATH"
    then 
        printError "Cannot create directory '$MOUNT_PATH' required for mount"
    fi
 
    LOOP_DEVICE_PATH=$(getLoopDeviceForImage "$IMAGE_PATH")
    if isStringEmpty "$LOOP_DEVICE_PATH"
    then 
        printError "Cannot create loop device for image: '$IMAGE_PATH'"
    fi
    
    for PARTITION in $(getPartitionsInDevice "$LOOP_DEVICE_PATH")
    do
        if [ "$PARTITION" = "${LOOP_DEVICE_PATH}p*" ]; 
        then 
            PARTITION="$LOOP_DEVICE_PATH"
        fi
        DESTINATION="$MOUNT_PATH/$(getPartitionLabel "$PARTITION")"
        if directoryExists "$DESTINATION" 
        then 
            doCommandAsStepWithSpinner "Waiting with umounting untill not busy" waitForUnmount "$DESTINATION"
            if isMountedOn "$PARTITION" "$DESTINATION"
            then 
                if ! doCommandAsStep "Unmounting of previous mounted partition on '$DESTINATION'" sudo umount "$DESTINATION"
                then 
                    if ! printQuestion "We could not unmount path '$DESTINATION' - do we can to use the force?" || ! doCommandAsStep "Unmounting of previous mounted partition on '$DESTINATION' with force" sudo umount -l "$DESTINATION"
                    then 
                        printError "Cannot unmount path: '$DESTINATION'. If you dont need it, please just unmount and it and remove it then"
                    fi
                fi
            elif ! isDirectoryEmpty "$DESTINATION"
            then 
                if printQuestion "Directory '$DESTINATION' is not empty. Do you need it?"
                then 
                    DESTINATION=$DESTINATION$RANDOM
                else 
                    removeDirectory "$DESTINATION"
                fi
            fi
        fi
        createDirectory "$DESTINATION"
        if ! doCommandAsStep "Mounting of partition '$PARTITION' to '$DESTINATION'" sudo mount "$PARTITION" "$DESTINATION"  
        then 
            printError "Cannot mount partition: $PARTITION"
        fi
    done
    return 0
}

#
#   Umounts an image
#
function umountImage()
{
    local IMAGE_PATH=$1
    local MOUNT_PATH=$2
    
    if ! fileExists "$IMAGE_PATH"
    then 
        printError "Cannot umount image '$IMAGE_PATH' - it does not exist!"
    fi
    
    LOOP_DEVICE_PATH=$(getLoopDeviceForImage "$IMAGE_PATH")
    if isStringEmpty "$LOOP_DEVICE_PATH"
    then 
        printError "Cannot create loop device for image: '$IMAGE_PATH'"
    fi   
    
    for PARTITION in $(getPartitionsInDevice "$LOOP_DEVICE_PATH")
    do
        if [ "$PARTITION" = "${LOOP_DEVICE_PATH}p*" ]; 
        then 
            PARTITION="$LOOP_DEVICE_PATH"
        fi
        
        DESTINATION="$MOUNT_PATH/$(getPartitionLabel "$PARTITION")"
        if isMountedOn "$PARTITION" "$DESTINATION"
        then
            doCommandAsStepWithSpinner "Waiting with umounting untill not busy" waitForUnmount "$DESTINATION"
            if ! doCommandAsStep "Unmounting of partition '$PARTITION' from '$DESTINATION'" sudo umount "$DESTINATION"
            then 
                if ! printQuestion "We could not unmount path '$DESTINATION' - do we can to use the force?" || ! doCommandAsStep "Unmounting of previous mounted partition on '$DESTINATION' with force" sudo umount -l "$DESTINATION"
                then 
                    printError "Cannot unmount path: '$DESTINATION'. If you dont need it, please just unmount and it and remove it then"
                fi
            fi
            removeDirectory "$DESTINATION"
        else 
            if ! doCommandAsStep "Unmounting of partition: '$PARTITION'" sudo umount -l "$PARTITION"
            then 
                printError "Cannot umount '$PARTITION'"
            fi
        fi
    done
    
    if isDirectoryEmpty "$MOUNT_PATH"
    then 
        removeDirectory "$MOUNT_PATH"
    fi
    removeLoopDeviceForImage "$IMAGE_PATH"
    return 0
}

#
#   Extracts archive
#
function extractFile()
{
    local INPUT_FILE=$1
    local OUTPUT_DIRECTORY=$2
    
    rm -rf "$OUTPUT_DIRECTORY"
    createDirectory "$OUTPUT_DIRECTORY"
    
    if [ ${INPUT_FILE: -4} == ".zip" ]
    then 
        setToolMandatory "unzip"
        doCommandAsStepWithSpinner "Extracting archive '$INPUT_FILE' to '$OUTPUT_DIRECTORY'" unzip $INPUT_FILE -d $OUTPUT_DIRECTORY
        return $?
    else 
        printError "Unknown file extension - cannot extract: $INPUT_FILE"
        return -1
    fi
}

#
#   Copying file to the selected destination
#
function copyFile()
{
    local INPUT_FILE=$1
    local OUTPUT_FILE=$2
    
    createDirectory "$(dirname "$OUTPUT_FILE")"
    doCommandAsStepWithSpinner "Copying file from '$INPUT_FILE' to '$OUTPUT_FILE'" cp "$INPUT_FILE" "$OUTPUT_FILE"
    return $?
}

#
#   Copying file to the selected destination
#
function copyFileAsRoot()
{
    local INPUT_FILE=$1
    local OUTPUT_FILE=$2
    
    createDirectory "$(dirname "$OUTPUT_FILE")"
    doCommandAsStepWithSpinner "Copying file from '$INPUT_FILE' to '$OUTPUT_FILE' as root" sudo cp "$INPUT_FILE" "$OUTPUT_FILE"
    return $?
}

#
#   Updates value of the variable in bash script
#
function updateVariableValueInBashFile()
{
    local FILE_NAME=$1
    local VAR_NAME=$2
    local NEW_VALUE=$3
    printInfo "Setting value of $VAR_NAME in $FILE_NAME to value: $NEW_VALUE\n"
    doCommand sed -i -e "'s/$VAR_NAME=.*$/$VAR_NAME=$NEW_VALUE/g'" "'$FILE_NAME'"
}

#
#   Returns group ID of current user
#
function getGroupId()
{
    echo "$(cut -d: -f3 < <(getent group sudo))"
}

#
#   Returns description of the required tool
#
function getRequiredToolDescription()
{
    local TOOL=$1
    echo "${__REQUIRED_TOOLS_DESCRIPTIONS[$TOOL]}"
}

#
#   Returns installation command for the tool
#
function getRequiredToolInstallationCommand()
{
    local TOOL=$1
    echo "${__REQUIRED_TOOLS_INSTALLATION_COMMAND[$TOOL]}"
}

#
#   Adds an argument type to the supported list
#
function __addSupportedArgumentType()
{
    local TYPE=$1
    local DESCRIPTION=$2
    local EXAMPLE=$3
    
    __SUPPORTED_ARGUMENT_TYPES+=($TYPE)
    __ARGUMENT_TYPE_DESCRIPTIONS[$TYPE]="$DESCRIPTION"
    __ARGUMENT_TYPE_EXAMPLES[$TYPE]="$EXAMPLE"
}

#
#   Checks if the given command exists
#
function commandExists()
{
    local COMMAND=$1
    type "$COMMAND" &> /dev/null
    RESULT=$?
    if [ $RESULT -eq 0 ]
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Stash local changes
#
function gitStashLocalChanges()
{
    local STASH_NAME="$1"
    printInfo "Stashing changes to '$STASH_NAME'\n"
    doCommand git stash save "$STASH_NAME"
}

#
#    Apply stash with name   
#
function gitApplyStashedChanges()
{
    local STASH_NAME="$1"
    printInfo "Restoring stashed changes from '$STASH_NAME'"
    doCommand git stash apply stash^{\\$STASH_NAME}
}

#
#   Creates branch name
#
function createGitBranchName()
{
    local BRANCH_NAME=$(echo "$1" | sed "s/[ ]/_/g" | sed "s/[^-/_a-Z0-9]//g")
    echo "$BRANCH_NAME"
}

#
#   Creates branch in GIT
#
function createGitBranch()
{
    local BRANCH_NAME=$(createGitBranchName "$1")
    if isStringEmpty "$BRANCH_NAME"
    then 
        printError "Cannot create branch - the name is empty"
    fi
    printInfo "Creating branch named: '$BRANCH_NAME'\n"
    doCommand git checkout -b "$BRANCH_NAME"
}

#
#   Switches to a given branch
#
function switchGitBranch()
{
    local BRANCH_NAME=$(createGitBranchName "$1")
    printInfo "Switching to branch $BRANCH_NAME\n"
    doCommand git checkout "$BRANCH_NAME"
}

#
#   Commits currently added changes
#
function gitCommit()
{
    local MESSAGE="$1"
    local MESSAGE_FILE=".git/commit_message"
    printInfo "Moving message to the temp file $MESSAGE_FILE\n"
    echo -e "$MESSAGE" > $MESSAGE_FILE
    printInfo "Commiting changes\n"
    doCommand git commit -F "$MESSAGE_FILE"
    printInfo "Commited with message: \n$MESSAGE\n"
}

#
#   Commits all local changes
#
function gitCommitAll()
{
    local MESSAGE="$1"
    printInfo "Adding all local changes to commit\n"
    doCommand git add ./*
    gitCommit "$MESSAGE"
}

#
#   Returns last tag from the git repository
#   
function getLastGitTag()
{
    git describe --tags --abbrev=0 @^
}

#
#   Removes double slashes from path
#
function normalizePath()
{
    local P=$1
    if commandExists "realpath"
    then 
        echo $(realpath -sm "$P")
    else 
        echo "$P"
    fi
}

#
#   Checks if the string contains substring 
#
function stringContainsSubstring()
{
    local STRING=$1
    local SUBSTRING=$2
    
    if [[ $STRING == *"$SUBSTRING"* ]]
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Converts a string to uppercase
#
function toUppercase()
{
    local STR=$1
    echo $STR | awk '{print toupper($0)}'
}

#
#   Extracts argument from dependency 
#
function getArgumentFromDependency()
{
    local DEPENDENCY=$1
    echo "${DEPENDENCY%=*}"
}

#
#   Extracts value from dependency 
# 
function getValueFromDependenncy()
{
    local DEPENDENCY=$1
    if stringContainsSubstring "$DEPENDENCY" "="
    then 
        echo "${DEPENDENCY#*=}"
    else 
        echo ""
    fi
}

#
#   Returns description of an argument type
#
function getArgumentTypeDescription()
{
    local TYPE=$1
    echo "${__ARGUMENT_TYPE_DESCRIPTIONS[$TYPE]}"
}

#
#   Returns example of an argument type
#
function getArgumentTypeExample()
{
    local TYPE=$1
    echo "${__ARGUMENT_TYPE_EXAMPLES[$TYPE]}"
}

#
#   Checks if directory is empty
#
function isDirectoryEmpty()
{
    local P=$1
    [ "$(ls -A $P)" ] && return 1 || return 0
}

#
#   Creates directory if it does not exists 
#
function createDirectory()
{
    local P=$1
    if doCommandAsVerification "Directory '$P' exists?" directoryExists "$P"
    then 
        return 0
    elif isPathWritable "$(dirname "$P")"
    then
        doCommandAsStep "Creating directory '$P'" mkdir -p $P
        if commandExists sudo
        then 
            doCommandAsStep "Changing owner of directory '$P' to $(id -u)" sudo chown -R $(id -u):$(id -g) "$P"
        fi
        return $?
    elif commandExists sudo
    then
        doCommandAsStep "Creating directory '$P' with sudo " sudo mkdir -p $P
        doCommandAsStep "Changing owner of directory '$P' to $(id -u)" sudo chown -R $(id -u):$(id -g) "$P"
        return $?
    fi
}

#
#   Deletes directory if it exists
#
function removeDirectory()
{
    local P=$1
    if ! doCommandAsStep "Verification of directory '$P'" directoryExists "$P"
    then 
        return 0
    else 
        doCommandAsStep "Removing directory '$P'" rm -rf "$P"
        return $?
    fi
}

# 
#   Removes file if it exists
#
function removeFile()
{
    local PATH=$1
    if [ -f $PATH ]
    then 
        rm $PATH
        return $?
    else
        return 0
    fi
}

#
#   Replaces substring in the string
#
function replaceInString()
{
    local STRING="$1"
    local IN="$2"
    local OUT="$3" 
    echo "$STRING" | sed "s/$IN/$OUT/g"
}

#
#   Replaces all occurrencies of '\n' to new line + intentation
#
function addIndentationToStringOnNewLine()
{
    local STRING="$1"
    local INTENTATION="$2"
    
    printf "$STRING" | sed "s/^/$INTENTATION/"
}

#
#   Splits the string by delimiter into an array
#
function splitStringByDelimited()
{
    local STRING=$1
    local DELIMITER=$2
    ARRAY=$(echo "$STRING" | tr "$DELIMITER" " ")
    echo "${ARRAY[*]}"
}

#
#   Checks if the given value is the expected argument, 
#   Example: 
#           BUILD_TYPE=X64
#           if isStringEqual$BUILD_TYPE x64
#           then
#               echo "Starting building X64"
#           fi
#
function isStringEqual()
{
    if [[ "${1,,}" == "${2,,}" ]]
    then 
        return 0
    else
        return 1
    fi
}

#
#   Checks if the string is empty
#
function isStringEmpty()
{
    local STRING=$1
    
    if [[ "$STRING" == "" ]]
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if the directory exists 
#
function directoryExists()
{
    local PATH=$1
    if [ -d "$PATH" ]
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if the file exists 
#
function fileExists()
{
    local PATH=$1
    if [ -f "$PATH" ]
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if the given value is integer 
# 
function isInteger()
{
    local VALUE=$1
    
    re='^[0-9]+$'
    
    if [[ $VALUE =~ $re ]]
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Returns first element of an array
#
function getFirstElementOfArray()
{
    local ARRAY=$1
    
    for element in ${ARRAY[*]}
    do
        echo "$element"
        return
    done
}

# 
#   Checks if the given string is available in the given array
#
function isInArray()
{
    local KEY=$1
    local ARRAY=$2
    
    for v in ${ARRAY[*]}
    do
        if isStringEqual "$v" "$KEY"
        then 
            return 0
        fi
    done
    return 1
}

#
#   Checks if the given tool is mandatory 
#
function isRequiredToolMandatory()
{
    local TOOL=$1
    if isStringEqual ${__REQUIRED_TOOLS_MANDATORY[$TOOL]} "TRUE"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if value for the given argument has been set 
#
function isArgumentValueSet()
{
    local ARGUMENT=$1
    if isStringEqual "${__ARGUMENT_VALUE_SET[$ARGUMENT]}" "TRUE"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if the given argument type is supported 
#   
function isArgumentTypeSupported()
{
    local ARGUMENT_TYPE=$1
    if isInArray "$ARGUMENT_TYPE" "${__SUPPORTED_ARGUMENT_TYPES[*]}"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if the given argument has been added to the supported list
#
function isKnownArgument()
{
    local ARGUMENT=$1
    if isInArray "$ARGUMENT" "${__ARGUMENTS[*]}"
    then 
        return 0
    else
        return 1
    fi
}

# 
#   Checks if the given argument is required argument 
#
function isArgumentRequired()
{
    local ARGUMENT=$1
    if isInArray "$ARGUMENT" "${__REQUIRED_ARGUMENTS[*]}"
    then 
        return 0
    else 
        return 1
    fi
}

# 
#   Checks if the given argument is optional 
#
function isArgumentOptional()
{
    local ARGUMENT=$1
    if ! isArgumentRequired "$ARGUMENT"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Checks if the argument type is set and if it is supported 
#   
function isArgumentTypeSet()
{
    local ARGUMENT=$1
    TYPE=$(getArgumentType $ARGUMENT)
    if [[ "$TYPE" == "" ]]
    then 
        return 1 
    else 
        if isArgumentTypeSupported $TYPE 
        then 
            return 0
        else 
            return 1
        fi
    fi
}

# 
#   Returns argument type 
#       Usage: ARGUMENT_TYPE=$(getArgumentType ARGUMENT)
#
function getArgumentType()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_TYPES[$ARGUMENT]}"
}

#
#   Checks if the given argument is equal to the expected type
# 
function isArgumentType()
{
    local ARGUMENT=$1
    local TYPE=$2
    
    if ! isArgumentTypeSupported $TYPE
    then 
        printError "The given argument type: $TYPE is not supported!"
    fi
    
    if isStringEqual "$(getArgumentType "$ARGUMENT")" "$TYPE"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   Returns argument description 
#       Usage: DESCRIPTION=$(getArgumentDescription ARGUMENT)
#
function getArgumentDescription()
{
    local ARGUMENT=$1 
    echo "${__ARGUMENT_DESCRIPTIONS[$ARGUMENT]}"
}

# 
#   Returns list of supported values for the given argument 
#       Usage: SUPPORTED_VALUES=$(getArgumentSupportedValues ARGUMENT)
#
function getArgumentSupportedValues()
{
    local ARGUMENT=$1 
    echo "${__ARGUMENT_SUPPORTED_VALUES[$ARGUMENT]}"
}

#
#   Returns regular expression for the argument
#
function getArgumentRegularExpression()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_REGULAR_EXPRESSIONS[$ARGUMENT]}"
}

#
#   Returns long name of the argument 
#
function getArgumentLongName()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_LONG_NAMES[$ARGUMENT]}"
}

#
#   Returns long name of the argument 
#
function getArgumentShortName()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_SHORT_NAMES[$ARGUMENT]}"
}

#
#   Checks if the long name for the given argument has been set 
#
function isArgumentLongNameSet()
{
    local ARGUMENT=$1
    if isStringEmpty "$(getArgumentLongName $ARGUMENT)"
    then
        return 1 
    else 
        return 0
    fi
}

#
#   Checks if the long name for the given argument has been set 
#
function isArgumentShortNameSet()
{
    local ARGUMENT=$1
    if isStringEmpty "$(getArgumentShortName $ARGUMENT)"
    then 
        return 1 
    else 
        return 0
    fi
}

#
#   Returns long argument name or short if the long is not set 
#
function getArgumentName()
{
    local ARGUMENT=$1
    if isArgumentLongNameSet "$ARGUMENT" 
    then 
        echo "$(getArgumentLongName "$ARGUMENT")"
    elif isArgumentShortNameSet "$ARGUMENT"
    then
        echo "$(getArgumentShortName "$ARGUMENT")"
    else 
        echo "$ARGUMENT"
    fi
}

#
#   Returns default value for the argument 
#
function getArgumentDefaultValue()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_DEFAULT_VALUES[$ARGUMENT]}"
}

#
#   Returns default value for the argument 
#
function getArgumentExampleValue()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_EXAMPLE_VALUES[$ARGUMENT]}"
}

#
#   Returns argument dependencies 
#
function getArgumentDependencies()
{
    local ARGUMENT=$1
    echo "${__ARGUMENT_DEPENDENCIES[$ARGUMENT]}"
}

#
#   Checks if the argument has dependencies 
#
function argumentHasDependencies()
{
    local ARGUMENT=$1
    DEPENDENCIES=$(getArgumentDependencies $ARGUMENT)
    
    if isStringEmpty "$DEPENDENCIES"
    then 
        return 1
    else 
        return 0
    fi
}

#
#   Checks if the value of the given argument is equal to the expected one
#
function isArgumentValueEqualTo()
{
    local ARGUMENT=$1
    local EXPECTED_VALUE=$2
    local VALUE
    
    VALUE=${!ARGUMENT}
    
    if isArgumentType "$ARGUMENT" "bool"
    then 
        if isStringEmpty "$VALUE"
        then 
            VALUE=$(getArgumentDefaultValue "$ARGUMENT")
        fi
        if isStringEmpty "$EXPECTED_VALUE"
        then 
            EXPECTED_VALUE="TRUE"
            if isStringEqual "$VALUE" "$EXPECTED_VALUE"
            then 
                return 0
            else 
                return 1
            fi
        fi
    fi
    
    if isStringEqual "$VALUE" "$EXPECTED_VALUE"
    then 
        return 0
    else 
        return 1
    fi
}

#
#   validates if all dependencies are passed 
#
function validateArgumentDependencies()
{
    local ARGUMENT=$1
    
    if ! isArgumentValueSet "$ARGUMENT"
    then 
        for dependency in $(getArgumentDependencies "$ARGUMENT")
        do
            DEPENDENCY_ARGUMENT=$(getArgumentFromDependency "$dependency")
            DEPENDENCY_VALUE=$(getValueFromDependenncy "$dependency")
            
            if isArgumentValueEqualTo "$DEPENDENCY_ARGUMENT" "$DEPENDENCY_VALUE"
            then 
                if isStringEmpty "$DEPENDENCY_VALUE"
                then 
                    printError "If argument '$(getArgumentName $DEPENDENCY_ARGUMENT)' is set, the field '$ARGUMENT' is mandatory. Please use $(getArgumentName $ARGUMENT) to set value"
                else 
                    printError "If argument '$(getArgumentName $DEPENDENCY_ARGUMENT)' is set to '$DEPENDENCY_VALUE', the field '$ARGUMENT' is mandatory. Please use $(getArgumentName $ARGUMENT) to set value"
                fi
                
            fi
        done
    fi
}

#
#   Validates all argument dependencies 
#
function validateDependencies()
{
    local ARGUMENT
    for ARGUMENT in ${__ARGUMENTS[*]}
    do
        validateArgumentDependencies "$ARGUMENT"
    done
}

#   
#   Checks if the given value of argument is valid
#
function validateArgumentValue()
{
    local ARGUMENT=$1
    local VALUE=$2
    
    ARGUMENT_TYPE=$(getArgumentType $ARGUMENT)
    
    if ! isArgumentTypeSet $ARGUMENT 
    then 
        printError "Type ($(getArgumentType $ARGUMENT)) for argument '$ARGUMENT' is not set or not supported."
    elif isArgumentType "$ARGUMENT" "int"
    then
        if isInteger "$VALUE"
        then 
            return 0
        else 
            printError "The given value: '$VALUE' for the argument $(getArgumentName $ARGUMENT) has to be an integer!"
            return 1
        fi
    elif isArgumentType "$ARGUMENT" "bool"
    then
        if isStringEqual "$VALUE" "true" || isStringEqual "$VALUE" "false" || isStringEmpty "$VALUE"
        then 
            return 0
        else 
            printError "The given value: '$VALUE' for the argument $(getArgumentName $ARGUMENT) has to be a bool!"
            return 1
        fi
    elif isArgumentType "$ARGUMENT" "options"
    then
        SUPPORTED_VALUES=$(getArgumentSupportedValues $ARGUMENT)
        if isStringEmpty "$VALUE"
        then 
            printError "Argument $(getArgumentName $ARGUMENT) cannot be empty. Supported values: $(getArgumentSupportedValues $ARGUMENT)"
        elif isInArray "$VALUE" "${SUPPORTED_VALUES[*]}"
        then 
            return 0
        else 
            printError "The given value: '$VALUE' for the argument $(getArgumentName $ARGUMENT) is not supported! Supported values: $(getArgumentSupportedValues $ARGUMENT)"
            return 1
        fi
    elif isArgumentType "$ARGUMENT" "regex"
    then
        REGULAR_EXPRESSION=$(getArgumentRegularExpression $ARGUMENT)
        if [[ "$VALUE" =~ ^$REGULAR_EXPRESSION$ ]] 
        then 
            return 0
        else 
            printError "The given value: '$VALUE' for the argument $(getArgumentName $ARGUMENT) does not match regular expression: '$REGULAR_EXPRESSION'"
        fi 
    elif isArgumentType "$ARGUMENT" "new_directory"
    then
        if directoryExists "$VALUE"
        then 
            printWarning "The given path: '$VALUE' for the argument $(getArgumentName $ARGUMENT) already exists - it will be removed"
            if removeDirectory "$VALUE"
            then 
                return 0
            else
                printError "The given path: '$VALUE' for the argument $(getArgumentName $ARGUMENT) already exists and cannot be removed"
                return 1
            fi
        fi
        
        if createDirectory "$VALUE"
        then 
            return 0
        else 
            printError "Cannot create directory: '$VALUE' for the argument $(getArgumentName $ARGUMENT)"
            return 1
        fi
    
    elif isArgumentType "$ARGUMENT" "existing_directory"
    then
        if directoryExists "$VALUE"
        then 
            return 0
        else 
            printError "The given directory: '$VALUE' required for argument $(getArgumentName $ARGUMENT) does not exist!"
            return 1
        fi
    elif isArgumentType "$ARGUMENT" "directory"
    then
        if directoryExists "$VALUE"
        then 
            return 0
        else 
            if createDirectory "$VALUE"
            then 
                return 0
            else
                printError "Directory: '$VALUE' for argument $(getArgumentName $ARGUMENT) does not exist and cannot be created!"
                return 1
            fi
        fi
    elif isArgumentType "$ARGUMENT" "output_file"
    then
        if fileExists "$VALUE"
        then 
            printWarning "The given path: '$VALUE' for the argument $(getArgumentName $ARGUMENT) already exists - it will be removed"
            if ! removeFile "$VALUE"
            then 
                printError "The given file: '$VALUE' required for argument $(getArgumentName $ARGUMENT) already exists and cannot be removed"
                return 1
            fi
        fi
        
        PARENT_DIR=$(dirname "$VALUE")
        if createDirectory "$PARENT_DIR"
        then 
            return 0
        else
            printError "Parent directory: '$PARENT_DIR' for the path: '$VALUE' for argument $(getArgumentName $ARGUMENT) does not exist and cannot be created"
            return 1
        fi 
    elif isArgumentType "$ARGUMENT" "existing_file"
    then
        if fileExists "$VALUE"
        then 
            return 0
        else 
            printError "The given file: '$VALUE' required for argument $(getArgumentName $ARGUMENT) does not exist!"
            return 1
        fi
    elif isArgumentType "$ARGUMENT" "file"
    then
        PARENT_DIR=$(dirname "$VALUE")
        if createDirectory "$PARENT_DIR"
        then 
            return 0
        else
            printError "Parent directory: '$PARENT_DIR' for the path: '$VALUE' for argument $(getArgumentName $ARGUMENT) does not exist and cannot be created"
            return 1
        fi 
    elif isArgumentType "$ARGUMENT" "not_empty_string"
    then
        if isStringEmpty "$VALUE"
        then 
            printError "The given string: '$VALUE' for argument: $(getArgumentName $ARGUMENT) cannot be empty!"
            return 1
        else 
            return 0
        fi
    elif isArgumentType "$ARGUMENT" "string"
    then
        return 0
    elif isArgumentType "$ARGUMENT" "password"
    then
        return 0
    else 
        printError "Unexpected argument type: $ARGUMENT_TYPE"
    fi 
}

#
#   Prints error message and exits from the script
#
function printError()
{
    local MESSAGE=$1
    local FINISH_SCRIPT=$2
    printf "\033[31;1m[ ERROR ] $MESSAGE\n\033[0m"
    if isStringEmpty "$FINISH_SCRIPT" || isStringEqual "$FINISH_SCRIPT" "TRUE"
    then 
        exit 1
    fi
}

#
#   Prints warning message 
#
function printWarning()
{
    printf "\033[33;1m[ WARNING ] $1\n\033[0m"
}

#
#   Prints info message
#
function printInfo()
{
    printf "\033[36;1m[ INFO ] \033[0;1m$1\033[0m"
}

#
#   Prints step message
#
function printStep()
{
    COLUMNS=$(tput cols)
    let MESSAGE_SIZE=$COLUMNS-38
    printf "\033[36;1m[ STEP ] \033[0;1m%-${MESSAGE_SIZE}s ... \033[39;1m[ \033[s       \033[39;1m]\033[u" "$1"
}

#
#   Prints step result 
#
function printStepResult()
{
    local RESULT=$1
    local DEATAILS=$2
    if [ $RESULT -eq 0 ]
    then 
        printf "\033[u\033[32;1m  OK  \033[0m\n"
        return 0
    else 
        printf "\033[u\033[31;1mFAILED\033[0m\n"
        if ! isStringEmpty "$DETAILS"
        then 
            printf "\033[31;1m%s\033[0m\n" "$DETAILS"
        fi
        return $RESULT
    fi
}


#
#   Prints verification message
#
function printVerification()
{
    COLUMNS=$(tput cols)
    let MESSAGE_SIZE=$COLUMNS-46
    printf "\033[36;1m[ VERIFICATION ] \033[0;1m%-${MESSAGE_SIZE}s ... \033[39;1m\033[s       \033[u" "$1"
}

#
#   Prints verification result 
#
function printVerificationResult()
{
    local RESULT=$1
    local DEATAILS=$2
    if [ $RESULT -eq 0 ]
    then 
        printf "\033[u\033[39;1mYES\033[0m\n"
        return 0
    else 
        printf "\033[u\033[39;1mNO\033[0m\n"
        if ! isStringEmpty
        then 
            printf "\033[31;1m%s\033[0m\n" "$DEATAILS"
        fi
        return $RESULT
    fi
}

#
#   Prints simple question with y/N answers and returns user result
#
function printQuestion()
{
    local QUESTION=$1
    local RESULT=1
    
    while 
        printf "\033[35;1m[ QUESTION ]\033[0m $QUESTION [y/N]: "
        read RESPONSE
        if isStringEqual "$RESPONSE" "y"
        then
            return 0
        elif isStringEqual "$RESPONSE" "N"
        then 
            return 1
        fi
    do
        :
    done
}

#
#   Prints question with string answer and returns 0 if success
#
function printQuestionWithStringAnswer()
{
    local __QUESTION="$1"
    local __VAR_NAME="$2"
    local __RESPONSE=""
    while
        printf "\033[35;1m[ QUESTION ]\033[0m $__QUESTION [ Type #exit to cancel ]: "
        read __RESPONSE
        if isStringEqual "$__RESPONSE" "#exit"
        then 
            return 1
        elif ! isStringEmpty "$__RESPONSE"
        then 
            eval $__VAR_NAME="'$__RESPONSE'"
            return 0
        fi
    do
        :
    done
}

#
#   Stores PID of last started spinned
#
export __SPINNER_PID=0
#
#   Process for printing of spinner 
#   
function __spin()
{
  spinner="/-\\|/-\\|"
  while :
  do
    for i in `seq 0 7`
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 1
    done
  done
}

#
#   Starts printing of spinner at current position
#
function startSpinner()
{
    # Start spinner process
    __spin &
    # Saves PID of spinner 
    __SPINNER_PID=$!
    # Kills the spinner on any signal
    #trap "kill -9 $__SPINNER_PID 2>&1 > /dev/null" `seq 0 15`
}

#
#   Stops printing of spinner 
#
function stopSpinner()
{
    #trap - `seq 0 15`
    kill -PIPE $__SPINNER_PID 2>&1 >/dev/null
}

#
#   Begins step
#
function beginStep()
{
    local MESSAGE=$1
    local WITH_SPINNER=$2
    printStep "$MESSAGE"
    if isStringEqual "$WITH_SPINNER" "TRUE"
    then 
        startSpinner
    fi
}

#
#   Finishes step
#
function finishStep()
{
    local RESULT=$1
    local DETAILS=$2
    local WITH_SPINNER=$3
    local COMMAND=$4
    if isStringEqual "$WITH_SPINNER" "TRUE"
    then 
        stopSpinner
    fi
    printStepResult $RESULT "$DETAILS Command: '$COMMAND'" 
}

#
#   Begins verification
#
function beginVerification()
{
    local MESSAGE=$1
    local WITH_SPINNER=$2
    printVerification "$MESSAGE"
    if isStringEqual "$WITH_SPINNER" "TRUE"
    then 
        startSpinner
    fi
}

#
#   Finishes verification
#
function finishVerification()
{
    local RESULT=$1
    local DETAILS=$2
    local WITH_SPINNER=$3
    if isStringEqual "$WITH_SPINNER" "TRUE"
    then 
        stopSpinner
    fi
    printVerificationResult $RESULT "$DETAILS"
}

#
#   Prints current configuration
#       Usage: printConfiguration VARIABLE_NAME1 VARIABLE_NAME2 ...
#
function printConfiguration()
{
    echo "========================================================="
    echo " Script name: $__SCRIPT_NAME"
    echo " Using configuration: "
    for arg in ${__ARGUMENTS[*]}
    do
        if isArgumentType "$arg" "password"
        then
            echo "          $arg: ************"
        else
            echo "          $arg: ${!arg} "
        fi
    done
    echo "========================================================="
}

#
#   Adds required tool to the list
#
function addRequiredTool()
{
    local TOOL=$1
    local NEED_DESCRIPTION=$2
    local MANDATORY=$3
    local INSTALLATION_COMMAND=$4
    
    if isStringEmpty "$TOOL"
    then 
        printError "Tool name cannot be empty"
    fi
    
    if isStringEmpty "$NEED_DESCRIPTION"
    then 
        printError "Cannot add tool '$TOOL' to the required list - the description cannot be empty"
    fi
    
    if isStringEmpty "$MANDATORY" 
    then 
        printError "Cannot add tool '$TOOL' to the required list - the mandatory field cannot be empty"
    fi
    
    if ! isStringEqual "$MANDATORY" "TRUE" && ! isStringEqual "$MANDATORY" "FALSE"
    then 
        printError "Cannot add tool '$TOOL' to the required list - the mandatory field can store only values 'TRUE' or 'FALSE'"
    fi
    
    __REQUIRED_TOOLS+=("$TOOL")
    __REQUIRED_TOOLS_DESCRIPTIONS[$TOOL]=$NEED_DESCRIPTION
    __REQUIRED_TOOLS_MANDATORY[$TOOL]=$MANDATORY
    __REQUIRED_TOOLS_INSTALLATION_COMMAND[$TOOL]=$INSTALLATION_COMMAND
}

#
#   Sets tool as mandatory
#
function setToolMandatory()
{
    local TOOL=$1
    
    __REQUIRED_TOOLS_MANDATORY[$TOOL]="TRUE"
    
    verifyRequiredTools
}

#
#   The function installs the required tool
#
function installRequiredTool()
{
    local TOOL=$1
    local ACCEPTED=$2
    
    if commandExists "$TOOL"
    then
        printError "Cannot install tool '$TOOL' - it is already installed"
    fi
    
    if isStringEmpty "$TOOL"
    then 
        printError "Cannot install tool - the name is not given! Possible tools: ${__REQUIRED_TOOLS[*]}"
    fi
    
    INSTALL_COMMAND=$(getRequiredToolInstallationCommand "$TOOL")
    
    if isStringEmpty "$INSTALL_COMMAND"
    then 
        printError "Cannot install tool '$TOOL' - the installation command is not defined"
    fi
    
    printInfo "Installation of tool '$TOOL'...\n"
    printInfo "Tool description: $(getRequiredToolDescription $TOOL)\n"
    printInfo "Installation command: '$(getRequiredToolInstallationCommand $TOOL)'\n"
    if ! isRequiredToolMandatory
    then 
        printInfo "The tool is marked as not mandatory for the script, but it is recommended\n"
    fi
    
    if ! isStringEqual "$ACCEPTED" "TRUE"
    then 
        if printQuestion "Do you want to continue installation of tool '$TOOL'?"
        then 
            ACCEPTED="TRUE"
        else
            printWarning "You did not agree for installation of tool '$TOOL' - skipping"
            return 1
        fi
    else 
        printInfo "Installation was preaccepted\n"
    fi
    
    COMMAND=$(getRequiredToolInstallationCommand "$TOOL")
    
    $COMMAND
}

#
#   Reads parameter from JSON
#
#   WARNING: jq tool is required for that
#
function readFromJson()
{
    local JSON=$1
    local PARAM_NAME=$2
    echo "$JSON" | jq -r ".$PARAM_NAME"
}

#
#   The function installs all required tools
#
function installAllRequiredTools()
{
    local ACCEPTED="FALSE"
    printInfo "Trying to install all tools required by the script\n"
    
    if ! isRoot
    then 
        if ! printQuestion "We have detected, that you are not logged as root. To avoid passing a password to all the commands separately, we propose you to use 'sudo su' command before the script. Do you want to continue anyway?"
        then 
            printInfo "Closing the script.\n"
            exit 0;
        fi
    fi
    
    if printQuestion "Do you want to accept the installation of all tools at once?"
    then 
        ACCEPTED="TRUE"
    fi
    
    for TOOL in ${__REQUIRED_TOOLS[*]}
    do
        printInfo "Verification of tool '$TOOL' ... "
        if ! commandExists "$TOOL" && ! isStringEmpty "$(getRequiredToolInstallationCommand "$TOOL")"
        then 
            printf "\033[33;1mNOT INSTALLED\n\033[0m"
            installRequiredTool "$TOOL" "$ACCEPTED"
        else 
            printf "\033[32;1mINSTALLED\n\033[0m"
        fi
    done
    
    printInfo "Installation finished\n"
    exit 0
}

#
#   The function prints list of all tools required by the script
#
function printAllRequiredToolsList()
{
    for TOOL in ${__REQUIRED_TOOLS[*]}
    do
        printf "\033[39;1m===================================================\n\n\033[0m"
        printf "    \033[39;1mTool name:\033[34;1m $TOOL\033[0m\n"
        DESCRIPTION=$(addIndentationToStringOnNewLine "$(getRequiredToolDescription $TOOL)" "                  ")
        printf "    \033[39;1mDescription: \033[0m \n$DESCRIPTION\n"
        printf "    \033[39;1mMandatory: \033[34;1m "
        if isRequiredToolMandatory "$TOOL"
        then 
            printf "YES\n"
        else 
            printf "NO\n"
        fi
        printf "    \033[39;1mInstallation command: \033[35;1m$(getRequiredToolInstallationCommand $TOOL)\n\n\033[0m"
    done
    exit 0
}

#
#   The function performs a command, with support of verbose mode
#
function doCommand()
{
    if isVerboseMode
    then 
        eval $@
        return $?
    else 
        local cmd=$@
        printf "\033[31;1m"
        eval $cmd > /dev/null
        local RESULT=$?
        printf "\033[0m"
        if [ $RESULT -eq 0 ]
        then 
            return 0
        else 
            return $RESULT
        fi
    fi
}

#
#   The function performs a command, with support of verbose mode
#
function doCommandAsStep()
{
    local DESCRIPTION="$1"
    local COMMAND=${@:2}
    if isVerboseMode
    then 
        printInfo "$DESCRIPTION\n"
        eval $COMMAND
        return $?
    else 
        beginStep "$DESCRIPTION" "FALSE"
        OUTPUT=$(eval $COMMAND 2>&1)
        #eval $COMMAND
        local RESULT=$?
        finishStep $RESULT "$OUTPUT" "FALSE" "$COMMAND"
        return $RESULT
    fi
}

#
#   The function performs a command, with support of verbose mode
#
function doCommandAsStepWithSpinner()
{
    local DESCRIPTION="$1"
    local COMMAND=${@:2}
    if isVerboseMode
    then 
        printInfo "$DESCRIPTION\n"
        eval $COMMAND
        return $?
    else 
        beginStep "$DESCRIPTION" "TRUE"
        OUTPUT=$(eval $COMMAND 2>&1)
        #eval $COMMAND
        local RESULT=$?
        finishStep $RESULT "$OUTPUT" "TRUE" "$COMMAND"
        #echo "COMMAND=$COMMAND"
        return $RESULT
    fi
}

#
#  The function performs a command with support of verification mode
#
function doCommandAsVerification()
{
    local DESCRIPTION="$1"
    local COMMAND=${@:2}
    if isVerboseMode
    then 
        printInfo "$DESCRIPTION\n"
        eval $COMMAND
        return $?
    else 
        beginVerification "$DESCRIPTION" "FALSE"
        OUTPUT=$($COMMAND 2>&1)
        local RESULT=$?
        finishVerification $RESULT "$OUTPUT" "FALSE"
    fi
}

#
#   The function performs a command, with support of verbose mode
#
function doCommandAsVerificationWithSpinner()
{
    local DESCRIPTION="$1"
    local COMMAND=${@:2}
    if isVerboseMode
    then 
        printInfo "$DESCRIPTION\n"
        eval $COMMAND
        return $?
    else 
        beginVerification "$DESCRIPTION" "TRUE"
        OUTPUT=$($COMMAND 2>&1)
        local RESULT=$?
        finishVerification $RESULT "$OUTPUT" "TRUE"
    fi
}

#   
#   sends a CURL request
#
function doCurlRequest()
{
    if isVerboseMode
    then 
        request_cmd=$(eval $@ -s -w "\\\\n%{http_code}")
        local result=$?
        response=(${request_cmd[@]}) # convert to array
        http_status=${response[-1]}
        output_response=${response[@]::${#response[@]}-1}
        echo "$request_cmd"
        if [ $result -eq 0 ] && [ "$http_status" == '200' ]
        then 
            printInfo "The request has been finished with success\n"
            openDataInBrowser "$output_response"
            return 0
        else
            printError "The request has been finished with failure. Status: $http_status\n" "FALSE"
            openDataInBrowser "$output_response"
            printError "Request failed"
            return 1
        fi
    else 
        local cmd=$@
        request_cmd=$(eval $cmd -s -w "\\\\n%{http_code}" 2>/dev/null )
        local RESULT=$?
        response=(${request_cmd[@]}) # convert to array
        http_status=${response[-1]}
        output_response=${response[@]::${#response[@]}-1}
        if [ $RESULT -eq 0 ] && [ "$http_status" == '200' ]
        then 
            printInfo "The request has been finished with success.\n"
            openDataInBrowser "$output_response"
            return 0
        else 
            printError "The request has been finished with failure. Status: $http_status" "FALSE"
            openDataInBrowser "$output_response"
            printError "Request failed"
            return $RESULT
        fi
    fi
}

#
#   Opens a HTML data in the default browser
#
function openDataInBrowser()
{
    local DATA="$1"
    local TEMP_FILE=$__CURL_OUTPUT_FILE
    if isStringEqual $__OPEN_BROWSER "FILE"
    then 
        echo "$DATA" > $TEMP_FILE
    elif isStringEqual $__OPEN_BROWSER "YES" || ( isStringEqual $__OPEN_BROWSER "PROMPT" && printQuestion "Do you want to open a HTML data in browser?" )
    then 
        echo "$DATA" > $TEMP_FILE
        doCommand see "$TEMP_FILE" 2>/dev/null
    else 
        echo -ne "\n\n\tOutput:\n\t\t$DATA\n\n"
    fi
}

#
#   Defines new script
#
function defineScript()
{
    local NAME=$1
    local DESCRIPTION=$2
    
    __SCRIPT_NAME=$NAME
    __SCRIPT_DESCRIPTION=$DESCRIPTION
}

#
#   Adds an argument name to the list
#
function addArgument()
{
    local ARGUMENT=$1
    local MANDATORY=$2
    
    if isKnownArgument "$ARGUMENT"
    then 
        printError "Cannot add argument: '$ARGUMENT' - it already exists!"
    fi
    
    if isStringEmpty "$ARGUMENT"
    then 
        printError "Cannot add argument - argument name cannot be empty!"
    fi
    
    __ARGUMENTS+=($ARGUMENT)
    __ARGUMENT_VALUE_SET[$ARGUMENT]="FALSE"
    
    if [[ $MANDATORY == "mandatory" ]]
    then 
        __REQUIRED_ARGUMENTS+=($ARGUMENT)
    fi
}

#
#   Verify that the argument has been added before
#
function verifyArgumentAdded()
{
    local ARGUMENT=$1
    
    if ! isKnownArgument $ARGUMENT 
    then 
        printError "The given argument is not added: '$ARGUMENT' - please add it first by using 'addArgument' function. List of known arguments: ${__ARGUMENTS[*]}"
    fi
}

#
#   Verify that the argument has been added before
#
function verifyArgumentTypeSet()
{
    local ARGUMENT=$1
    
    if ! isArgumentTypeSet "$ARGUMENT"
    then 
        printError "The given argument type is not set: '$ARGUMENT' - please set the type first. List of supported types: ${__SUPPORTED_ARGUMENT_TYPES[*]}"
    fi
}

#
#   Sets CLI names for the given argument
#
function setArgumentNames()
{
    local ARGUMENT=$1
    local CLI_NAMES=$2
    LONG_NAME=""
    SHORT_NAME=""
    
    verifyArgumentAdded "$ARGUMENT"
    
    if isStringEmpty "$CLI_NAMES"
    then 
        printError "Command line names cannot be empty for argument: $ARGUMENT. The received values: '$CLI_NAMES'. Please add options like: '-v|--verbose' or '--verbose'"
    fi
    
    declare -a CLI_NAMES_ARRAY
 
    CLI_NAMES_ARRAY="$(splitStringByDelimited "$CLI_NAMES" "|")"

    for name in ${CLI_NAMES_ARRAY[*]}
    do
        if [ ${#name} -ge ${#LONG_NAME} ]
        then 
            SHORT_NAME=$LONG_NAME
            LONG_NAME=$name
        else 
            SHORT_NAME=$name
        fi 
    done
    
    __ARGUMENT_LONG_NAMES[$ARGUMENT]=$LONG_NAME
    __ARGUMENT_SHORT_NAMES[$ARGUMENT]=$SHORT_NAME
}

#
#   Sets argument type
#
function setArgumentType()
{
    local ARGUMENT=$1
    local TYPE=$2
    
    verifyArgumentAdded "$ARGUMENT"
    
    if isStringEmpty "$TYPE"
    then 
        printError "Cannot set argument type for: '$ARGUMENT' - it is empty! The supported list: ${__SUPPORTED_ARGUMENT_TYPES[*]}"
    fi
    
    if ! isArgumentTypeSupported "$TYPE"
    then 
        printError "The given argument type: '$TYPE' is not supported. List of supported types: ${__SUPPORTED_ARGUMENT_TYPES[*]}"
    fi
    
    __ARGUMENT_TYPES[$ARGUMENT]="$TYPE"
}

#
#   Sets argument description 
#
function setArgumentDescription()
{
    local ARGUMENT=$1
    local DESCRIPTION=$2
    
    verifyArgumentAdded "$ARGUMENT"
    
    if isStringEmpty "$DESCRIPTION"
    then 
        printError "Description for the argument '$ARGUMENT' cannot be empty!"
    fi
    
    __ARGUMENT_DESCRIPTIONS[$ARGUMENT]=$DESCRIPTION
}

#
#   Sets argument supported values
#
function setArgumentSupportedValues()
{
    local ARGUMENT=$1
    local SUPPORTED_VALUES=$2
    
    verifyArgumentAdded "$ARGUMENT"
    verifyArgumentTypeSet "$ARGUMENT"
    
    if ! isArgumentType "$ARGUMENT" "options" && ! isStringEmpty "${SUPPORTED_VALUES[*]}"
    then 
        printError "Supported values cannot be set for argument '$ARGUMENT' - it can be set only for arguments of type 'options'"
    fi
    
    if isArgumentType "$ARGUMENT" "options" && isStringEmpty "${SUPPORTED_VALUES[*]}"
    then 
        printError "Supported values for '$ARGUMENT' are not given - it is required to set list of supported values in case of argument of type 'options'"
    fi
    
    __ARGUMENT_SUPPORTED_VALUES[$ARGUMENT]=${SUPPORTED_VALUES[*]}
}

#
#   Sets regular expression for the argument 
#
function setArgumentRegularExpression()
{
    local ARGUMENT=$1
    local REGULAR_EXPRESSION=$2
    
    verifyArgumentAdded "$ARGUMENT"
    verifyArgumentTypeSet "$ARGUMENT"
    
    if ! isArgumentType "$ARGUMENT" "regex" && ! isStringEmpty "$REGULAR_EXPRESSION"
    then 
        printError "Regular expression cannot be set for argument '$ARGUMENT' - it can be set only for arguments of type 'regex'"
    fi 
    
    if isArgumentType "$ARGUMENT" "regex" && isStringEmpty "$REGULAR_EXPRESSION"
    then 
        printError "Regular expression for argument '$ARGUMENT' is not given - it is required to set regular expression for type 'regex'"
    fi
    
    __ARGUMENT_REGULAR_EXPRESSIONS[$ARGUMENT]=$REGULAR_EXPRESSION
}

#
#   Sets default value for the given argument
#
function setArgumentDefaultValue()
{
    local ARGUMENT=$1
    local DEFAULT_VALUE=$2
    
    verifyArgumentAdded "$ARGUMENT"
    verifyArgumentTypeSet "$ARGUMENT"
    
    validateArgumentValue "$ARGUMENT" "$DEFAULT_VALUE"
    
    __ARGUMENT_DEFAULT_VALUES[$ARGUMENT]=$DEFAULT_VALUE
}

#
#   Sets example value for default argument
#
function setArgumentExampleValue()
{
    local ARGUMENT=$1
    local EXAMPLE_VALUE=$2
    
    verifyArgumentAdded "$ARGUMENT"
    verifyArgumentTypeSet "$ARGUMENT"
    
    if isArgumentType "$ARGUMENT" "regex" && isStringEmpty "$EXAMPLE_VALUE"
    then 
        printError "Example value for argument '$ARGUMENT' is not set. It is required to set an example for 'regex' type"
    fi
    
    if ! isStringEmpty "$EXAMPLE_VALUE"
    then 
        validateArgumentValue "$ARGUMENT" "$EXAMPLE_VALUE"
    
        __ARGUMENT_EXAMPLE_VALUES[$ARGUMENT]=$EXAMPLE_VALUE
    fi
}

#
#   Sets dependences for the given argument 
#
function setArgumentDependencies()
{
    local ARGUMENT=$1
    local DEPENDENCIES=$2
    
    verifyArgumentAdded "$ARGUMENT"
    verifyArgumentTypeSet "$ARGUMENT"
    
    for DEPENDENCY in ${DEPENDENCIES[*]}
    do
        DEPENDENCY_ARGUMENT=$(getArgumentFromDependency "$DEPENDENCY")
        VALUE=$(getValueFromDependenncy "$DEPENDENCY")
        if ! isKnownArgument "$DEPENDENCY_ARGUMENT"
        then 
            printError "Cannot add dependency '$DEPENDENCY' for argument: $ARGUMENT - you have to add argument '$DEPENDENCY_ARGUMENT' before '$ARGUMENT'"
        fi
        VALIDATION_RESULT=$(validateArgumentValue "$DEPENDENCY_ARGUMENT" "$VALUE")
        if [[ ! $? -eq 0 ]]
        then 
            printError "Cannot add dependency '$DEPENDENCY' for argument $ARGUMENT. The given value is not valid: \n$VALIDATION_RESULT"
        fi
    done
    
    __ARGUMENT_DEPENDENCIES[$ARGUMENT]=${DEPENDENCES[*]}
}

# 
#   Adds new command line required argument to the list
#
function addCommandLineRequiredArgument()
{
    local ARGUMENT=$1
    local CLI_NAMES=$2
    local TYPE=$3
    local DESCRIPTION=$4
    local SUPPORTED_VALUES=$5
    local REGULAR_EXPRESSION=$5
    local EXAMPLE_VALUE=$6
    
    addArgument "$ARGUMENT" "mandatory"
    setArgumentNames "$ARGUMENT" "$CLI_NAMES"
    setArgumentType "$ARGUMENT" "$TYPE"
    setArgumentDescription "$ARGUMENT" "$DESCRIPTION"
    if isArgumentType "$ARGUMENT" "regex"
    then 
        setArgumentRegularExpression "$ARGUMENT" "$REGULAR_EXPRESSION"
    elif isArgumentType "$ARGUMENT" "options"
    then
        setArgumentSupportedValues "$ARGUMENT" "${SUPPORTED_VALUES[*]}"
    else 
        EXAMPLE_VALUE=$REGULAR_EXPRESSION
    fi
    
    setArgumentExampleValue "$ARGUMENT" "$EXAMPLE_VALUE"
}

#
#   Adds new command line required argument with dependences
#       Dependences means, that the this argument is required only 
#       if the dependences are also set to TRUE
#
function addCommandLineRequiredArgumentWithDependencies()
{
    local ARGUMENT=$1
    local CLI_NAMES=$2
    local TYPE=$3
    local DESCRIPTION=$4
    local DEPENDENCES=$5
    local DEFAULT_VALUE=$6
    local SUPPORTED_VALUES=$7
    local REGULAR_EXPRESSION=$7
    local EXAMPLE_VALUE=$8
    
    addArgument "$ARGUMENT" "optional"
    setArgumentNames "$ARGUMENT" "$CLI_NAMES"
    setArgumentType "$ARGUMENT" "$TYPE"
    setArgumentDescription "$ARGUMENT" "$DESCRIPTION"
    if isArgumentType "$ARGUMENT" "regex"
    then 
        setArgumentRegularExpression "$ARGUMENT" "$REGULAR_EXPRESSION"
    elif isArgumentType "$ARGUMENT" "options"
    then
        setArgumentSupportedValues "$ARGUMENT" "${SUPPORTED_VALUES[*]}"
    else 
        EXAMPLE_VALUE=$REGULAR_EXPRESSION
    fi
    setArgumentDefaultValue "$ARGUMENT" "$DEFAULT_VALUE"
    setArgumentExampleValue "$ARGUMENT" "$EXAMPLE_VALUE"
    setArgumentDependencies "$ARGUMENT" "${DEPENDENCES[*]}"
}

# 
#   Adds new command line optional argument to the list
#
function addCommandLineOptionalArgument()
{
    local ARGUMENT=$1
    local CLI_NAMES=$2
    local TYPE=$3
    local DESCRIPTION=$4
    local DEFAULT_VALUE=$5
    local SUPPORTED_VALUES=$6
    local REGULAR_EXPRESSION=$6
    local EXAMPLE_VALUE=$7
    
    addArgument "$ARGUMENT" "optional"
    setArgumentNames "$ARGUMENT" "$CLI_NAMES"
    setArgumentType "$ARGUMENT" "$TYPE"
    setArgumentDescription "$ARGUMENT" "$DESCRIPTION"
    if isArgumentType "$ARGUMENT" "regex"
    then 
        setArgumentRegularExpression "$ARGUMENT" "$REGULAR_EXPRESSION"
    elif isArgumentType "$ARGUMENT" "options"
    then
        setArgumentSupportedValues "$ARGUMENT" "${SUPPORTED_VALUES[*]}"
    else 
        EXAMPLE_VALUE=$REGULAR_EXPRESSION
    fi
    setArgumentDefaultValue "$ARGUMENT" "$DEFAULT_VALUE"
    setArgumentExampleValue "$ARGUMENT" "$EXAMPLE_VALUE"
}

#
#   Prints Usage() message 
#
function printUsage()
{   
    local ARGUMENT
    printf "  To see the help please use: \n\t\033[33;1m$__SCRIPT_NAME --help"
    printf "\033[0m\n"
    printf "  Usage: \n\t\033[33;1m$__SCRIPT_NAME "
    for ARGUMENT in ${__ARGUMENTS[*]}
    do
        if isArgumentOptional "$ARGUMENT"
        then
            printf "["
        fi
        
        SHORT_NAME=$(getArgumentShortName $ARGUMENT)
        LONG_NAME=$(getArgumentLongName $ARGUMENT)
        if isArgumentType "$ARGUMENT" "bool"
        then 
            if isStringEmpty "$SHORT_NAME"
            then 
                echo -ne "$LONG_NAME"
            elif isStringEmpty "$LONG_NAME"
            then 
                echo -ne "$SHORT_NAME"
            else 
                echo -ne "$SHORT_NAME|$LONG_NAME"
            fi
        else 
            if isStringEmpty "$SHORT_NAME"
            then 
                echo -ne "$LONG_NAME=<value>"
            elif isStringEmpty "$LONG_NAME"
            then
                echo -ne "$SHORT_NAME=<value"
            else 
                echo -ne "$SHORT_NAME|$LONG_NAME=<value>"
            fi
        fi
        
        if isArgumentOptional "$ARGUMENT"
        then
            printf "] "
        else 
            printf " "
        fi
    done
    printf "\033[0m\n\n"
}

#
#   Prints Help() message
#
function printHelp()
{
    printf "=======================================================================================\n"
    printf "                                       HELP                                              \n"
    printf "=======================================================================================\n\n"
    printf "The script '\033[32m$__SCRIPT_NAME\033[0m'\n\n"
    printf "$__SCRIPT_DESCRIPTION\n\n"
    printUsage
    printf "\n      \033[39;1mwhere:\033[0m\n\n"
    
    for ARGUMENT in ${__ARGUMENTS[*]}
    do
        LONG_NAME=$(getArgumentLongName "$ARGUMENT")
        SHORT_NAME=$(getArgumentShortName "$ARGUMENT")
        ARGUMENT_TYPE=$(getArgumentType $ARGUMENT)
        ARGUMENT_DESCRIPTION=$(addIndentationToStringOnNewLine "$(getArgumentDescription $ARGUMENT)" "                                 ")
        ARGUMENT_TYPE_DESCRIPTION=$(addIndentationToStringOnNewLine "$(getArgumentTypeDescription $ARGUMENT_TYPE)" "                                 ")
        printf "            \033[34;1m"
        if isArgumentType "$ARGUMENT" "bool"
        then 
            if isStringEmpty "$SHORT_NAME"
            then 
                echo -ne "$LONG_NAME"
            elif isStringEmpty "$LONG_NAME"
            then 
                echo -new "$SHORT_NAME"
            else 
                echo -ne "$SHORT_NAME,$LONG_NAME"
            fi
        else 
            if isStringEmpty "$SHORT_NAME"
            then 
                echo -ne "$LONG_NAME=*"
            elif isStringEmpty "$LONG_NAME"
            then 
                echo -ne "$SHORT_NAME=*"
            else 
                echo -ne "$SHORT_NAME=*,$LONG_NAME=*"
            fi
        fi
        if isArgumentRequired "$ARGUMENT"
        then 
            printf "\033[31;1m [MANDATORY] "
        fi
        
        if argumentHasDependencies "$ARGUMENT"
        then 
            printf "\033[33;1m [DEPENDENCIES] \033[0m\n\n"
            printf "\033[33;1m                       This argument can be mandatory if at least one of dependencies is passed\n\n"
            printf "                       \033[39;1mList of dependencies: \033[0m$(getArgumentDependencies $ARGUMENT)\033[0m\n"
        fi
        
        printf "\033[0m\n"
        printf "                       \033[39;1mArgument name: \033[0m$ARGUMENT\033[0m\n"
        printf "                       \033[39;1mArgument type: \033[33;1m$(getArgumentType $ARGUMENT)\033[0m\n"
        printf "                       \033[39;1mType description: \n\n\033[0m$ARGUMENT_TYPE_DESCRIPTION\033[0m\n\n"
        if isArgumentOptional "$ARGUMENT"
        then 
            printf "                       \033[39;1mDefault value: \033[33;1m$(getArgumentDefaultValue $ARGUMENT)\033[0m\n"
        fi
        printf "                       \033[39;1mValue description: \n\n\033[0m$ARGUMENT_DESCRIPTION\033[0m\n\n"
        
        if isArgumentType "$ARGUMENT" "options"
        then 
            printf "                       \033[39;1mSupported values: \n\n\033[0m"
            echo -ne "                                 $(getArgumentSupportedValues $ARGUMENT)"
            printf "\033[0m\n\n"
        elif isArgumentType "$ARGUMENT" "regex"
        then 
            printf "                       \033[39;1mRegular expression: \n\n\033[0m"
            echo -ne "                                 $(getArgumentRegularExpression $ARGUMENT)"
            printf "\033[0m\n\n"
        fi
        
        printf "                       \033[39;1mExample of usage: \n\n\033[0m"
        printf "\033[0m"
            
        if ! isArgumentType "$ARGUMENT" "bool"
        then 
            if isArgumentType "$ARGUMENT" "options"
            then 
                declare -A SUPPORTED_VALUES
                SUPPORTED_VALUES="$(getArgumentSupportedValues "$ARGUMENT")"
                EXAMPLE_VALUE=$(getArgumentExampleValue "$ARGUMENT")
                if isStringEmpty "$EXAMPLE_VALUE"
                then 
                    EXAMPLE_VALUE=$(getFirstElementOfArray "${SUPPORTED_VALUES[*]}")
                fi
                if ! isStringEmpty "$LONG_NAME"
                then 
                    printf "\033[35;1m"
                    echo "                                 $__SCRIPT_NAME $LONG_NAME=$EXAMPLE_VALUE"
                fi
                if ! isStringEmpty "$SHORT_NAME" && ! isStringEmpty "$LONG_NAME"
                then 
                    printf "                             \033[39;1mor\033[35;1m\n"
                fi
                if ! isStringEmpty "$SHORT_NAME"
                then 
                    echo "                                 $__SCRIPT_NAME $SHORT_NAME=$EXAMPLE_VALUE"
                    printf "\033[0m"
                fi
            elif isArgumentType "$ARGUMENT" "regex"
            then 
                EXAMPLE="$(getArgumentExampleValue "$ARGUMENT")"
                if ! isStringEmpty "$LONG_NAME"
                then 
                    printf "\033[35;1m"
                    echo "                                 $__SCRIPT_NAME $LONG_NAME=\"$EXAMPLE\""
                fi
                if ! isStringEmpty "$SHORT_NAME" && ! isStringEmpty "$LONG_NAME"
                then 
                    printf "                             \033[39;1mor\033[35;1m\n"
                fi
                if ! isStringEmpty "$SHORT_NAME"
                then 
                    echo "                                 $__SCRIPT_NAME $SHORT_NAME=\"$EXAMPLE\""
                fi
            else
                local EXAMPLE=$(getArgumentExampleValue "$ARGUMENT")
                if isStringEmpty "$EXAMPLE"
                then 
                    EXAMPLE=$(getArgumentTypeExample "$ARGUMENT_TYPE")
                fi
                if ! isStringEmpty "$LONG_NAME"
                then 
                    printf "\033[35;1m"
                    echo "                                 $__SCRIPT_NAME $LONG_NAME=\"$EXAMPLE\""
                fi
                if ! isStringEmpty "$SHORT_NAME" && ! isStringEmpty "$LONG_NAME"
                then 
                    printf "                             \033[39;1mor\033[35;1m\n"
                fi
                if ! isStringEmpty "$SHORT_NAME"
                then 
                    echo "                                 $__SCRIPT_NAME $SHORT_NAME=\"$EXAMPLE\""
                fi
            fi
        else
            if ! isStringEmpty "$LONG_NAME"
            then 
                printf "\033[35;1m"
                echo "                                 $__SCRIPT_NAME $LONG_NAME"
            fi
            if ! isStringEmpty "$SHORT_NAME" && ! isStringEmpty "$LONG_NAME"
            then 
                printf "                             \033[39;1mor\033[35;1m\n"
            fi
            if ! isStringEmpty "$SHORT_NAME"
            then 
                echo "                                 $__SCRIPT_NAME $SHORT_NAME=FALSE"
                printf "\033[0m"
            fi
        fi
        
        printf "\n\n"
    done
    exit 0
}

# 
#   Sets value of the argument
#
function setArgumentValue()
{
    local ARGUMENT=$1
    local VALUE="$2"
    verifyArgumentAdded "$ARGUMENT"
    verifyArgumentTypeSet "$ARGUMENT"
    validateArgumentValue "$ARGUMENT" "$VALUE"
    
    __ARGUMENT_VALUE_SET[$ARGUMENT]="TRUE"
    local ESCAPED_1=$(replaceInString "$VALUE" "<" "\\\\<")
    local ESCAPED_2=$(replaceInString "$ESCAPED_1" ">" "\\\\>")
    eval $ARGUMENT="'$ESCAPED_2'"
}

#
#   Verify if all required tools are installed 
#
function verifyRequiredTools()
{
    for tool in ${__REQUIRED_TOOLS[*]}
    do
        if ! commandExists "$tool"
        then 
            if isRequiredToolMandatory "$tool"
            then 
                printError "The tool: '$tool' is not installed, but it is mandatory for the script: $(getRequiredToolDescription $tool) To install the tool, you can use --install script argument. For more information please check --help"
            else 
                printWarning "The tool '$tool' is not installed, but the script is able to work without it. Anyway it is recommended to install it: $(getRequiredToolDescription $tool). To install the tool, you can use --install script argument. For more information please check --help"
            fi
            
        fi
    done
}

#
#   Parses all defined command line arguments
#
function parseCommandLineArguments()
{
    for i in "$@"
    do
    case $i in
        -h|--help)
        printHelp
        shift # past argument=value
        ;;
        *)
        for ARGUMENT in ${__ARGUMENTS[*]}
        do
            SHORT_NAME=$(getArgumentShortName "$ARGUMENT")
            LONG_NAME=$(getArgumentLongName "$ARGUMENT")
            case $i in
                $SHORT_NAME|$LONG_NAME)
                if isArgumentType "$ARGUMENT" "bool"
                then 
                    setArgumentValue "$ARGUMENT" "TRUE"
                else 
                    setArgumentValue "$ARGUMENT" ""
                fi
                shift
                ;;
                $SHORT_NAME=*|$LONG_NAME=*)
                VALUE="${i#*=}"
                setArgumentValue "$ARGUMENT" "$VALUE"
                shift
                ;;
            esac
        done
        shift
        ;;
    esac
    done
    
    if isArgumentValueSet "__TOOL_TO_INSTALL"
    then 
        installRequiredTool "$__TOOL_TO_INSTALL"
    fi
    
    if isArgumentValueSet "__INSTALL_ALL_REQUIRED"
    then 
        installAllRequiredTools
    fi
    
    if isArgumentValueSet "__PRINT_REQUIRED_TOOLS_LIST"
    then 
        printAllRequiredToolsList
    fi
    
    validateDependencies
    verifyRequiredTools
    
    for ARGUMENT in ${__ARGUMENTS[*]}
    do
        if ! isArgumentValueSet "$ARGUMENT"
        then 
            if isArgumentRequired "$ARGUMENT"
            then 
                printUsage 
                printError "Argument: '$(getArgumentName $ARGUMENT)' - is mandatory, but you did not set it"
            else
                VALUE=$(getArgumentDefaultValue "$ARGUMENT")
                setArgumentValue "$ARGUMENT" "$VALUE"
            fi
        fi
    done
    
    validateDependencies
    printConfiguration "${__ARGUMENTS[*]}"
}

__addSupportedArgumentType "int" "A type that allows only for passing integer values" "2832"
__addSupportedArgumentType "bool" "Boolean type for storing only 'TRUE' or 'FALSE' value. \nYou dont have to pass value for this argument. If the argument is given to the script \nwithout value, it is set to TRUE" "FALSE"
__addSupportedArgumentType "options" "This argument type allows for choosing only from predefined list of supported values" ""
__addSupportedArgumentType "new_directory" "Takes a path to new directory. If the directory already exists, it will be removed first" "/my/path/to/not/existing/directory/"
__addSupportedArgumentType "existing_directory" "This type of argument expects a path, that does exist when the script is run. \nIf the path does not exist, it will not be created and the script will fail" "/my/path/to/existing/directory/"
__addSupportedArgumentType "directory" "A path to a directory - If it does not exist, it will be created" "/my/path/to/some/directory/"
__addSupportedArgumentType "output_file" "It is a destination path for the output file. \nIf it already exist, it will be removed by the script" "/build/my_output_file.txt"
__addSupportedArgumentType "existing_file" "This argument type expects a path to the existing file. \nIf the file does not exist, the script will fail" "/lib/my_existing_library_file.a"
__addSupportedArgumentType "file" "A path to the file that can, but does not have to exist. \nIf the file does not exist, the script will create one" "/var/usr/my_config_file.json"
__addSupportedArgumentType "not_empty_string" "This type of argument allows for passing strings, but the string cannot be empty" "some_string"
__addSupportedArgumentType "string" "This type of argument allows for passing strings and the string can be empty" "some string but it can be also empty"
__addSupportedArgumentType "password" "This type of argument allows for passing strings that can be empty. Moreover they will be printed in the configuration as stars" "***********"
__addSupportedArgumentType "regex" "This type of argument allows for passing strings that can only store a string that matches the regular expression" "2018-09-12"

addRequiredTool "realpath" "The tool is used for normalization of paths. If it will be not installed, \nthe paths can be ugly - for example they can have double slashes" "FALSE" "sudo apt-get install realpath -y"
addRequiredTool "wget" "GNU Wget is a free software package for retrieving files using HTTP, HTTPS, FTP and FTPS the most widely-used Internet protocols. It is a non-interactive commandline tool, so it may easily be called from scripts, cron jobs, terminals without X-Windows support, etc. It is required by a script for pulling of files" "FALSE" "sudo apt-get update && sudo apt-get install -y wget"
addRequiredTool "unzip" "unzip will list, test, or extract files from a ZIP archive, commonly found on MS-DOS systems.\nIt is used by the script to extract zip archives" "FALSE" "sudo apt-get install -y unzup"
addRequiredTool "sudo" "A command for bash allowing for performing of commands with root privileges without loging as root. It is used by script for installation of tools, creation of paths etc. This is the only tool you have to install as root" "TRUE" "apt-get install -y sudo"
addRequiredTool "htpasswd" "A tool required for bcrypt password encryption" "FALSE" "sudo apt-get install -y apache2-utils"
addRequiredTool "php" "Engine for PHP scripts." "FALSE" "sudo apt-get install -y php"

addCommandLineOptionalArgument __TOOL_TO_INSTALL "--install-required-tool" "options" "You can use this option to install tool required by this script" "realpath" "${__REQUIRED_TOOLS[*]}"
addCommandLineOptionalArgument __INSTALL_ALL_REQUIRED "--install-all-required" "bool" "You can use this argument to install all tools required by the script" "FALSE"
addCommandLineOptionalArgument __PRINT_REQUIRED_TOOLS_LIST "--print-required-tools" "bool" "Prints list of all tools required by the script with description" "FALSE"
addCommandLineOptionalArgument __OPEN_BROWSER "--open-browser" "options" "Allows for opening HTML data in browser" "PROMPT" "YES NO PROMPT FILE"
addCommandLineOptionalArgument __CURL_OUTPUT_FILE "--curl-output-file" "file" "Name of output file for CURL requests" "/tmp/tmp$RANDOM.html"
addCommandLineOptionalArgument VERBOSE "--verbose" "bool" "If the option is enabled, the script will keep printing all information from commands, otherwise it will print only the errors" "FALSE"
