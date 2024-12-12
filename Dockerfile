FROM debian:bookworm-slim as base
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

FROM archlinux:latest AS wine-builder

ENV XDG_CACHE_HOME /tmp/.cache

# Build wine-tkg-ntsync
FROM debian:bookworm as wine-builder
USER root
WORKDIR /opt
RUN dpkg --add-architecture i386 && apt update
RUN apt install -y aptitude curl git tar
RUN aptitude remove -y '?narrow(?installed,?version(deb.sury.org))'
RUN curl --create-dirs -o /usr/include/linux/ntsync.h https://raw.githubusercontent.com/zen-kernel/zen-kernel/6.8/main/include/uapi/linux/ntsync.h
RUN git clone --depth 1 https://github.com/kangtastic/wine-tkg-ntsync.git

WORKDIR /opt/wine-tkg-ntsync/
RUN cd wine-tkg-git && \
    sed -i 's/ntsync="false"/ntsync="true"/' ./customization.cfg && \
    sed -i 's/esync="true"/esync="false"/' ./customization.cfg && \
    sed -i 's/fsync="true"/fsync="false"/' ./customization.cfg && \
    sed -i 's/_NOLIB32="false"/_NOLIB32="wow64"/' ./wine-tkg-profiles/advanced-customization.cfg && \
    echo '_ci_build="true"' >> ./customization.cfg

RUN cd wine-tkg-git && yes|./non-makepkg-build.sh
RUN cp -r $(find . -type d -name wine-tkg-staging-ntsync-git*) /wine-tkg-ntsync

FROM base

ARG WINE_BRANCH="devel"

COPY --from=wine-builder /wine-tkg-ntsync /wine-tkg-ntsync
WORKDIR /

# latest winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks \
    && chmod +x /usr/local/bin/winetricks

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

ENV HOME=/
ENV WINEPREFIX=/.wine
ENV WINEARCH=win64

WORKDIR /

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

ENV TERM=xterm

# wine-ge
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    cron \
    xz-utils
RUN mkdir /wine-ge && \
    curl -sL "https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton8-26/wine-lutris-GE-Proton8-26-x86_64.tar.xz" | tar xvJ -C /wine-ge
RUN mv /wine-ge/lutris-GE-Proton8-26-x86_64/* /wine-ge

ENV WINE_NTSYNC_BIN_PATH=/wine-tkg-ntsync/bin
ENV WINE_BIN_PATH=/wine-ge/bin

#ENV PATH=$WINE_NTSYNC_BIN_PATH:$WINE_BIN_PATH:$PATH

# Add wine repos and install stable wine
# This is required to run wineboot properly
RUN sudo mkdir -pm755 /etc/apt/keyrings \
    && sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} zstd libc-bin libc6 \
    && rm -rf /var/lib/apt/lists/*

# Install wineprefix deps
RUN winetricks -q arial times
# Cache vcredist installer direct from MS to bypass downloading from web.archive.org
RUN mkdir -p /.cache/winetricks/ucrtbase2019
RUN curl -SL 'https://download.visualstudio.microsoft.com/download/pr/85d47aa9-69ae-4162-8300-e6b7e4bf3cf3/14563755AC24A874241935EF2C22C5FCE973ACB001F99E524145113B2DC638C1/VC_redist.x86.exe' \
    -o /.cache/winetricks/ucrtbase2019/VC_redist.x86.exe
RUN curl -SL 'https://download.visualstudio.microsoft.com/download/pr/85d47aa9-69ae-4162-8300-e6b7e4bf3cf3/52B196BBE9016488C735E7B41805B651261FFA5D7AA86EB6A1D0095BE83687B2/VC_redist.x64.exe' \
    -o /.cache/winetricks/ucrtbase2019/VC_redist.x64.exe
RUN winecfg && wineboot --update && xvfb-run -a winetricks -q vcrun2019 dotnetdesktop8


COPY ./scripts/purge_logs.sh /usr/bin/purge_logs
COPY ./data/cron/cron_purge_logs /opt/cron/cron_purge_logs

# Copy over all modified reg files to prefix in container
# Wineprefix set overrides winhttp n,b for bepinex
COPY ./data/reg/user.reg /.wine/
COPY ./data/reg/system.reg /.wine/

# Copy nvidia init script
COPY ./scripts/install_nvidia_deps.sh /opt/scripts/


COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
