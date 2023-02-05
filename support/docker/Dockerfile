# SPDX-License-Identifier: GPL-2.0-or-later
# copied from Buildroot 2022.02.9
# and then updated:
# - to not point to Buildroot mailing list or docker hub
# - to use up-to-date base image
# - to allow multiple layers on docker to improve regeneration of image
# - to use the minimal number of packages installed

# This Dockerfile generates the docker image that gets used by Gitlab CI
# Build it using 'make docker-image'

# latest snapshot from https://hub.docker.com/_/debian
FROM debian:bookworm-20230202

LABEL maintainer="Ricardo Martincoski <ricardo.martincoski@gmail.com>" \
      description="Container with everything needed to run utootlkm-uml"

# The container has no package lists, so need to update first
RUN apt-get update -y

RUN apt-get install -y --no-install-recommends \
        bc \
        bison \
        build-essential \
        flex \
        && echo done installing linux dependencies

RUN apt-get install -y --no-install-recommends \
        ca-certificates \
        cpio \
        file \
        rsync \
        unzip \
        wget \
        && echo done installing rootfs_initial dependencies

RUN apt-get install -y --no-install-recommends \
        fakeroot \
        && echo done installing rootfs_extract dependencies

RUN apt-get install -y --no-install-recommends \
        git \
        && echo done installing GitLab CI dependencies

RUN apt-get -y autoremove && \
    apt-get -y clean

RUN useradd -ms /bin/bash br-user && \
    chown -R br-user:br-user /home/br-user

USER br-user
WORKDIR /home/br-user
ENV HOME /home/br-user
