FROM debian:bookworm
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
    iproute2 \
    procps \
    kmod \
    libc6-dev \
    libpci3 \
    libelf-dev \
    dbus-x11 \
    xauth \
    xcvt \
    xserver-xorg-core \
    xvfb

ARG WINE_BRANCH="devel"

# Add wine repos and install stable wine
RUN sudo mkdir -pm755 /etc/apt/keyrings \
    && sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# latest winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks \
    && chmod +x /usr/local/bin/winetricks

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

ENV HOME /
ENV WINEPREFIX /.wine

# winetricks dotnet48 doesn't install on win64
ENV WINEARCH win64

WORKDIR /

# Install wineprefix deps
# Have to run these separately for some reason or else they fail
RUN winetricks arial times 
# Cache vcredist installer direct from MS to bypass downloading from web.archive.org
RUN mkdir -p /.cache/winetricks/ucrtbase2019
RUN curl -SL 'https://download.visualstudio.microsoft.com/download/pr/85d47aa9-69ae-4162-8300-e6b7e4bf3cf3/14563755AC24A874241935EF2C22C5FCE973ACB001F99E524145113B2DC638C1/VC_redist.x86.exe' \
    -o /.cache/winetricks/ucrtbase2019/VC_redist.x86.exe
RUN curl -SL 'https://download.visualstudio.microsoft.com/download/pr/85d47aa9-69ae-4162-8300-e6b7e4bf3cf3/52B196BBE9016488C735E7B41805B651261FFA5D7AA86EB6A1D0095BE83687B2/VC_redist.x64.exe' \
    -o /.cache/winetricks/ucrtbase2019/VC_redist.x64.exe
RUN xvfb-run -a winetricks -q vcrun2019 dotnetdesktop8

ENV PROFILE_ID=test
ENV SERVER_URL=127.0.0.1
ENV SERVER_PORT=6969

# Nvidia container toolkit stuff, for nvidia-xconfig
ENV DISPLAY_SIZEW=1024
ENV DISPLAY_SIZEH=768
ENV DISPLAY_REFRESH=60
ENV DISPLAY_DPI=96
ENV DISPLAY_CDEPTH=24
ENV VIDEO_PORT=DFP

# Force TERM to xterm because sometimes it gets set to "dumb" for some reason ???
ENV TERM=xterm

# Copy over all modified reg files to prefix in container
# Wineprefix set overrides winhttp n,b for bepinex
COPY ./data/reg/user.reg /.wine/
COPY ./data/reg/system.reg /.wine/

# Copy nvidia init script
COPY ./scripts/install_nvidia_deps.sh /opt/scripts/

RUN winetricks dxvk wmp9
RUN winetricks vd=1920x1080

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    cron \
    xz-utils

# wine-ge
RUN mkdir /wine-ge && \
    curl -sL "https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton8-26/wine-lutris-GE-Proton8-26-x86_64.tar.xz" | tar xvJ -C /wine-ge
ENV WINE_BIN_PATH=/wine-ge/lutris-GE-Proton8-26-x86_64/bin

# system wine
#ENV WINE_BIN_PATH=/usr/bin

# wine-tkg
#RUN mkdir /wine-tkg && \
#    curl -sL "https://github.com/Kron4ek/Wine-Builds/releases/download/9.20/wine-9.20-staging-tkg-amd64.tar.xz" | tar xvJ -C /wine-tkg
#ENV WINE_BIN_PATH=/wine-tkg/wine-9.20-staging-tkg-amd64/bin

# proton9
#RUN mkdir /proton && \
#    curl -sL "https://github.com/Kron4ek/Wine-Builds/releases/download/proton-9.0-3/wine-proton-9.0-3-amd64.tar.xz" | tar xvJ -C /proton
#ENV WINE_BIN_PATH=/proton/wine-proton-9.0-3-amd64/bin

# proton-exp
#RUN mkdir /proton-exp && \
#    curl -sL "https://github.com/Kron4ek/Wine-Builds/releases/download/proton-exp-9.0/wine-proton-exp-9.0-amd64.tar.xz" | tar xvJ -C /proton-exp
#ENV WINE_BIN_PATH=/proton-exp/wine-proton-exp-9.0-amd64/bin

ENV WINE=$WINE_BIN_PATH/wine64
ENV PATH=$WINE_BIN_PATH:$PATH

COPY ./scripts/purge_logs.sh /usr/bin/purge_logs
COPY ./data/cron/cron_purge_logs /opt/cron/cron_purge_logs

COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
