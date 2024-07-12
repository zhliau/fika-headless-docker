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

FROM ubuntu:24.04

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
    pkg-config \
    libxext6 \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools \
    sudo \

    # Nvidia driver install deps
    kmod \
    libc6-dev \
    libpci3 \
    libelf-dev \
    dbus-x11 \

    # OpenGL libraries
    libxau6 \
    libxdmcp6 \
    libxcb1 \
    libxext6 \
    libx11-6 \
    libxv1 \
    libxtst6 \
    libdrm2 \
    libegl1 \
    libgl1 \
    libopengl0 \
    libgles1 \
    libgles2 \
    libglvnd0 \
    libglx0 \
    libglu1 \
    libsm6 \

    x11-apps \
    x11-utils \
    x11-xserver-utils \
    xserver-xorg-video-all \
    xcvt \
    xvfb

# Install VirtualGL
#RUN wget -q -O- https://packagecloud.io/dcommander/virtualgl/gpgkey | \
#  gpg --dearmor >/etc/apt/trusted.gpg.d/VirtualGL.gpg
#RUN wget -nv https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list -O /etc/apt/sources.list.d/VirtualGL.list
#RUN apt update && apt install -y virtualgl

# Install TurboVNC
#RUN wget -nv https://github.com/TurboVNC/turbovnc/releases/download/3.1.1/turbovnc_3.1.1_amd64.deb -O /opt/turbovnc.deb
#RUN apt install -y -f /opt/turbovnc.deb

# Disable screen lock
RUN echo "[Daemon]\n\
    Autolock=false\n\
    LockOnResume=false" > /etc/xdg/kscreenlockerrc

ARG WINE_BRANCH="devel"

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


ENV PASSWD=asdfasdf
# Add user to run the client
# user 1000 on host maps to ubuntu in container (also UID 1000)
RUN echo "ubuntu ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "ubuntu:${PASSWD}" | chpasswd

USER ubuntu
ENV HOME /home/ubuntu
ENV WINEPREFIX /home/ubuntu/.wine

# winetricks dotnet48 doesn't install on win64
ENV WINEARCH win64

WORKDIR /home/ubuntu

# Install wineprefix deps
# Have to run these separately for some reason or else they fail
RUN winetricks arial times 
RUN xvfb-run -a winetricks -q vcrun2019

ENV PROFILE_ID=test
ENV SERVER_URL=127.0.0.1
ENV SERVER_PORT=6969

ENV XDG_RUNTIME_DIR=/tmp/runtime-ubuntu
ENV DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/tmp}/dbus-session-${DISPLAY#*:}"
ENV DISPLAY=:0
ENV DISPLAY_SIZEW=1920
ENV DISPLAY_SIZEH=1080
ENV DISPLAY_REFRESH=60
ENV DISPLAY_DPI=96
ENV DISPLAY_CDEPTH=24
ENV VIDEO_PORT=DFP

# Copy over all modified reg files to prefix in container
# Wineprefix set overrides winhttp n,b for bepinex
COPY ./data/reg/user.reg /home/ubuntu/.wine/
COPY ./data/reg/system.reg /home/ubuntu/.wine/

# Copy nvidia init script
COPY ./scripts/install_nvidia_deps.sh /opt/scripts/

COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
