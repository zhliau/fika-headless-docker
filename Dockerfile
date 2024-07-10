# Dedicated client docker
# Host must have nvidia-container-toolkit if using Nvidia DGPU
# 
# Mount Fika client at /opt/tarkov
# Make sure Fika.Core and Fika.dedicated are in plugins folder
# Mount live files to /opt/live
# 
# TODO
# - Port forwards? Do we need to set a new port for this dedicated client?
# - modify fika core config as part of dockerfile?

FROM ubuntu:20.04

# ENV WINE_MONO_VERSION 9.2.0
USER root

ARG DEBIAN_FRONTEND=noninteractive

ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV NVIDIA_VISIBLE_DEVICES=all

# Set the timezone
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && \
    apt-get install -y tzdata && \
    dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    vim \
    locales \
    gnupg \
    gosu \
    gpg-agent \
    curl \
    unzip \
    ca-certificates \
    cabextract \
    git \
    wget \
    libxext6 \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools \
    dxvk \
    xvfb

# RUN setup_dxvk install

ARG WINE_BRANCH="stable"

# Add wine repos and install stable wine
RUN wget -nv -O- https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && echo "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" >> /etc/apt/sources.list \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# latest winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks \
    && chmod +x /usr/local/bin/winetricks

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

# Add user to run the client
RUN useradd -ms /bin/bash fika

USER fika
ENV HOME /home/fika
ENV WINEPREFIX /home/fika/.wine

# winetricks dotnet48 doesn't install on win64
ENV WINEARCH win64

WORKDIR /home/fika
# Init wine prefix by starting a random program without DISPLAY, this will crash but that's okay
#RUN wine hostname

# Install wineprefix deps
# Have to run these separately for some reason or else they fail
RUN winetricks arial times 
RUN xvfb-run -a winetricks -q vcrun2019

ENV PROFILE_ID=test
ENV SERVER_URL=127.0.0.1
ENV SERVER_PORT=6969

# Copy over all modified reg files to prefix in container
# Wineprefix set overrides winhttp n,b for bepinex
COPY ./data/reg/user.reg /home/fika/.wine/
COPY ./data/reg/system.reg /home/fika/.wine/

COPY entrypoint.sh /usr/bin/entrypoint
COPY init_xvfb /opt/
ENTRYPOINT ["/usr/bin/entrypoint"]
