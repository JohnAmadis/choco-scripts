FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y p7zip-full

RUN mkdir -p /scripts/
COPY public /scripts/
