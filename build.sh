#!/bin/bash

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SCRIPTS_DIR=$PROJECT_DIR/public

. $SCRIPTS_DIR/functions.sh

#
#   Variables
#
IMAGE_NAME=chocotechnologies/scripts
PACKAGE_NAME=choco-scripts
PUBLIC_DIR=$SCRIPTS_DIR
PACKAGE_DIR=public/scripts
VERSION_FILE=$PUBLIC_DIR/version

#
#   The function prepares a functions.sh script to work
#
function prepareScript()
{
    defineScript "$0" "The script is responsible for building of images"
    
    addCommandLineRequiredArgument TARGET "-t|--target" "options" "Target of the build, where 'package' allows for building of 7z package with the script, 'builder' allows for building of image required for building 'package' and 'image' builds docker image with the scripts." "package builder image" 
    addCommandLineRequiredArgument VERSION "-v|--version" "not_empty_string" "Version of the image to build" "V.1.0.0"
    addCommandLineOptionalArgument PUBLISH_URL "-u|--url" "not_empty_string" "URL to use to publish the packages" "chocotecdz-release@ssh.cluster023.hosting.ovh.net"
    
    parseCommandLineArguments "$@"
}

#
#   Creates version file 
#
function createVersionFile()
{
    printInfo "Preparation of version file at $VERSION_FILE\n" 
    echo "${VERSION/V./}" > $VERSION_FILE
}

#
#   Builds the image
#
function buildImage()
{
    createVersionFile
    doCommandAsStep "Building of image $IMAGE_NAME:${VERSION/V./}" docker build -t "$IMAGE_NAME:${VERSION/V./}" --build-arg VERSION=${VERSION/V./} -f Dockerfile .
    doCommandAsStep "Tagging of image $IMAGE_NAME:${VERSION/V./} as $IMAGE_NAME:latest" docker tag "$IMAGE_NAME:${VERSION/V./}" "$IMAGE_NAME:latest"
    doCommandAsStep "Pushing of the image $IMAGE_NAME:${VERSION/V./}" docker push $IMAGE_NAME:${VERSION/V./}
    doCommandAsStep "Pushing of the image $IMAGE_NAME:latest" docker push $IMAGE_NAME:latest
}

#
#   Builds the image for building images
#
function buildBuilderImage()
{
    createVersionFile
    doCommandAsStep "Building of image $IMAGE_NAME:builder" docker build -t "$IMAGE_NAME:builder" -f Dockerfile.builder .
    doCommandAsStep "Pushing of the image $IMAGE_NAME:builder" docker push $IMAGE_NAME:builder
}

#
#   Builds a package with the scripts
#
function buildPackage()
{
    createVersionFile
    PACKAGE_FILE_NAME=$PACKAGE_NAME-${VERSION/V./}.tar.gz
    PACKAGE_FILE_PATH=$PROJECT_DIR/$PACKAGE_FILE_NAME
    LATEST_PACKAGE_FILE_NAME=$PACKAGE_NAME-latest.tar.gz
    cd $PUBLIC_DIR
    doCommandAsStep "Building of package $PACKAGE_FILE_PATH" tar -czf $PACKAGE_FILE_PATH *
    cd $PROJECT_DIR
    doCommandAsStep "Creating a directory $PACKAGE_DIR in the remote host" ssh $PUBLISH_URL mkdir -p $PACKAGE_DIR
    doCommandAsStep "Publishing of package $PACKAGE_FILE_NAME" scp "$PACKAGE_FILE_NAME" "$PUBLISH_URL":$PACKAGE_DIR/$PACKAGE_FILE_NAME
    doCommandAsStep "Publishing of package $LATEST_PACKAGE_FILE_NAME" scp "$PACKAGE_FILE_NAME" "$PUBLISH_URL":$PACKAGE_DIR/$LATEST_PACKAGE_FILE_NAME
}

#
#   Main
#
prepareScript "$@"

if isStringEqual "$TARGET" "image"
then 
    buildImage
elif isStringEqual "$TARGET" "builder"
then 
    buildBuilderImage
else
    buildPackage
fi
