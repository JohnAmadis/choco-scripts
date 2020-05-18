#
#   Building arguments
#
ARG VERSION=latest

# 
#   Release image for the scripts
#
FROM ubuntu:18.04

#
#   Installation of wget for installation script
#
RUN apt-get update
RUN apt-get install -y wget

#
#   Creating directory for the scripts 
#
RUN mkdir /scripts/

#
#   Coping installation script
#
COPY install-choco-scripts.sh /scripts/

#
#   Installation of the 
#
RUN /scripts/install-choco-scripts.sh /scripts/ $VERSION
