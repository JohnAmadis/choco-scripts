# 
#   Release image for the scripts
#
FROM ubuntu:18.04

#
#   Creating directory for the scripts 
#
RUN mkdir /scripts/

#
#   Coping scripts
#
COPY public /scripts/
