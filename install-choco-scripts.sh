#!/bin/bash
#
#   The script is for installation of the choco-scripts in your repository
#
#       VERSION: 1.0.0
#
#

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
FILE_NAME=choco-scripts-latest.tar.gz
URL=http://release.choco-technologies.com/scripts/$FILE_NAME
TARGET_PATH=$PROJECT_DIR/choco-scripts
TEMPLATE_FILE_PATH=$TARGET_PATH/template.sh

if [ "$1" == "--help" ]
then 
    echo "The script will help you with installation of the choco-scripts at the selected path."
    echo "For this installation you will need only wget which you can install by using your package manager"
    echo "By default it will be installed in '$TARGET_PATH'"
    echo "Usage:"
    echo "        $0 [target_path]"
    exit 0
elif [ ! "$1" == "" ]
then
    TARGET_PATH=$1
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
if [ ! $result -eq 0 ]
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


printf "\033[32;1mCongratulations, the choco-scripts in version $(cat $TARGET_PATH/version) are now installed at $TARGET_PATH.\033[0m\n"
echo "You can use file $TEMPLATE_FILE_PATH as a template for your scripts"
