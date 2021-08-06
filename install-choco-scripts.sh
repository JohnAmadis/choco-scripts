#!/bin/bash
#
#   The script is for installation of the choco-scripts in your repository
#
#       VERSION: 1.0.4
#
#

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
VERSION=latest
FILE_NAME=choco-scripts-$VERSION.tar.gz
URL=http://release.choco-technologies.com/scripts/$FILE_NAME
TARGET_PATH=~/.choco-scripts
TEMPLATE_FILE_NAME=template.sh
TEMPLATE_FILE_PATH=$TARGET_PATH/$TEMPLATE_FILE_NAME
CREATE_CHOCO_SCRIPT_FILE_NAME=create_choco_script.sh
CREATE_CHOCO_SCRIPT_FILE_PATH=$TARGET_PATH/$CREATE_CHOCO_SCRIPT_FILE_NAME
USER_CONFIG_PATH=~/.choco-scripts.cfg
BASHRC_FILE_PATH=~/.bashrc
ENTRY_SCRIPT_NAME=choco-scripts

if [ "$1" == "--help" ]
then 
    echo "The script will help you with installation of the choco-scripts at the selected path."
    echo "For this installation you will need only wget which you can install by using your package manager"
    echo "By default it will be installed in '$TARGET_PATH'"
    echo "Usage:"
    echo "        $0 [target_path] [version]"
    exit 0
else 
    if [ ! "$1" == "" ]
    then
        TARGET_PATH=$1
    fi
    if [ ! "$2" == "" ]
    then
        VERSION=$2
        FILE_NAME=choco-scripts-$VERSION.tar.gz
    fi
fi

#
#   Checks if the command is available
#
function isCommandAvailable()
{
    local cmd=$1
    command -v $cmd > /dev/null 2>&1
    return $?
}

if ! isCommandAvailable wget
then 
    echo "Sorry, but you need to install 'wget' first. If you are using debian-based system you can do it by using command:"
    echo "sudo apt-get install -y wget"
    exit 1
fi

wget $URL -O $FILE_NAME
result=$?
if [ ! $result -eq 0 ]
then 
    echo "Cannot get choco-scripts from $URL - please verify the URL is still valid"
    exit 1
fi

mkdir -p $TARGET_PATH
result=$?
if [ ! $result -eq 0 ]bash
then 
    echo "Creation of the target directory '$TARGET_PATH' not possible - maybe some privileges are missing?"
    exit 1
fi

tar -xf $FILE_NAME -C $TARGET_PATH
result=$?
if [ ! $result -eq 0 ]
then 
    echo "Extraction of the package $FILE_NAME was not possible"
fi

echo "*" > $TARGET_PATH/.gitignore
rm $FILE_NAME

echo "export CHOCO_SCRIPTS_PATH=$TARGET_PATH" > $USER_CONFIG_PATH
echo "export CHOCO_SCRIPT_ENTRY_FILE_NAME=$ENTRY_SCRIPT_NAME" >> $USER_CONFIG_PATH
echo "export CHOCO_SCRIPT_TEMPLATE_FILE_NAME=$TEMPLATE_FILE_NAME" >> $USER_CONFIG_PATH
echo "export CHOCO_SCRIPT_CREATE_CHOCO_SCRIPT_FILE_NAME=$CREATE_CHOCO_SCRIPT_FILE_NAME" >> $USER_CONFIG_PATH
echo "export CHOCO_SCRIPTS_VERSION=$(cat $TARGET_PATH/version)" >> $USER_CONFIG_PATH
echo 'export PATH="$PATH:$CHOCO_SCRIPTS_PATH"' >> $USER_CONFIG_PATH
echo "function getChocoScriptsPath()" >> $USER_CONFIG_PATH
echo "{" >> $USER_CONFIG_PATH
echo '   echo "$CHOCO_SCRIPTS_PATH/$CHOCO_SCRIPT_ENTRY_FILE_NAME"' >> $USER_CONFIG_PATH
echo "}" >> $USER_CONFIG_PATH
echo "function getChocoTemplatePath()" >> $USER_CONFIG_PATH
echo "{" >> $USER_CONFIG_PATH
echo '   echo "$CHOCO_SCRIPTS_PATH/$CHOCO_SCRIPT_TEMPLATE_FILE_NAME"' >> $USER_CONFIG_PATH
echo "}" >> $USER_CONFIG_PATH
echo "function createChocoScript()" >> $USER_CONFIG_PATH
echo "{" >> $USER_CONFIG_PATH
echo '   "$CHOCO_SCRIPTS_PATH/$CHOCO_SCRIPT_CREATE_CHOCO_SCRIPT_FILE_NAME" $@   ' >> $USER_CONFIG_PATH
echo "}" >> $USER_CONFIG_PATH
echo 'printf "\033[37;1mHello, Choco scripts are installed in version \033[35;1m$CHOCO_SCRIPTS_VERSION\033[37;1m in the path \033[35;1m$CHOCO_SCRIPTS_PATH\033[0m\n"' >> $USER_CONFIG_PATH
echo 'printf "\033[37;1mPlease use command \033[36;1msource \$(getChocoScriptsPath)\033[37;1m to import it in your project\033[0m\n"' >> $USER_CONFIG_PATH

if ! cat "$BASHRC_FILE_PATH" | grep "source $USER_CONFIG_PATH" > /dev/null 2>&1
then 
    echo "source $USER_CONFIG_PATH" >> $BASHRC_FILE_PATH
fi

source $USER_CONFIG_PATH

printf "\033[32;1mCongratulations, the choco-scripts in version $VERSION are now installed at $TARGET_PATH\033[0m\n"
printf "You can use file \033[37;1m$(getChocoTemplatePath)\033[0m as a template for your scripts\n"
printf "or just call function \033[37;1mcreateChocoScript\033[0m\n"
echo "To import choco-scripts in your script, just add: "
printf '\033[35;1msource $(getChocoScriptsPath)\033[0m\n'
