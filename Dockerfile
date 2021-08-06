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
#   Installation of the choco-scripts
#
RUN /scripts/install-choco-scripts.sh /scripts/ $VERSION

#
#   Disabling interactive mode
#
ENV DEBIAN_FRONTEND=noninteractive

#
#   Some installation in the packages are interactive, so we 
#   want to force noninteractive mode
#
RUN ln -fs /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
RUN apt-get install -y tzdata
RUN dpkg-reconfigure --frontend noninteractive tzdata
RUN apt-get install -y sudo

#
#   Installs all tools required by the template script by default
#
RUN cp /scripts/template.sh /tmp/dummy_script.sh
RUN sed "s/<SCRIPT_ARGUMENTS>//g" -i "/tmp/dummy_script.sh"
RUN /tmp/dummy_script.sh --install-all-required --non-interactive
