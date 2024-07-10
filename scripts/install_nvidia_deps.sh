#!/bin/bash

# Most of this code is cribbed from the entrypoint of the selkies docker-nvidia-glx-desktop project
# https://github.com/selkies-project/docker-nvidia-glx-desktop

sudo rm -rf /tmp/.X* ~/.cache || echo 'Failed to clean X11 paths'

# Install Nvidia driver package using same version as host
if ! command -v nvidia-xconfig >/dev/null 2>&1; then
  # Install NVIDIA userspace driver components including X graphic libraries
  export NVIDIA_DRIVER_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64/' -e 's/armhf/32bit-ARM/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')"
  if [ -z "${NVIDIA_DRIVER_VERSION}" ]; then
    # Driver version is provided by the kernel through the container toolkit, prioritize kernel driver version if available
    if [ -f "/proc/driver/nvidia/version" ]; then
      export NVIDIA_DRIVER_VERSION="$(head -n1 </proc/driver/nvidia/version | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9\.]+/) {print $i; exit}}')"
    elif command -v nvidia-smi >/dev/null 2>&1; then
      # Use NVIDIA-SMI when not available
      export NVIDIA_DRIVER_VERSION="$(nvidia-smi --version | grep 'DRIVER version' | cut -d: -f2 | tr -d ' ')"
    else
      echo 'Failed to find NVIDIA GPU driver version, container will likely not start because of no NVIDIA container toolkit or NVIDIA GPU driver present'
    fi
  fi
  cd /tmp
  # If version is different, new installer will overwrite the existing components
  if [ ! -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Check multiple sources in order to probe both consumer and datacenter driver versions
    curl -fsSL -O "https://international.download.nvidia.com/XFree86/Linux-${NVIDIA_DRIVER_ARCH}/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || curl -fsSL -O "https://international.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || echo 'Failed NVIDIA GPU driver download'
  fi
  if [ -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Extract installer before installing
    rm -rf "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
    sh "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" -x
    cd "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
    # Run NVIDIA driver installation without the kernel modules and host components
    sudo ./nvidia-installer --silent \
                      --no-kernel-module \
                      --install-compat32-libs \
                      --no-nouveau-check \
                      --no-nvidia-modprobe \
                      --no-systemd \
                      --no-rpms \
                      --no-backup \
                      --no-check-for-alternate-installs
    rm -rf /tmp/NVIDIA* && cd ~
  else
    echo 'Unless using non-NVIDIA GPUs, container will likely not work correctly'
  fi
fi

echo "Configuring Xorg"
# Xorg
# Allow starting Xorg from a pseudoterminal instead of strictly on a tty console
if [ ! -f /etc/X11/Xwrapper.config ]; then
    echo -e "allowed_users=anybody\nneeds_root_rights=yes" | sudo tee /etc/X11/Xwrapper.config > /dev/null
fi
if grep -Fxq "allowed_users=console" /etc/X11/Xwrapper.config; then
    sudo sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config
fi

# Remove existing Xorg configuration
if [ -f "/etc/X11/xorg.conf" ]; then
    sudo rm -f "/etc/X11/xorg.conf"
fi

if [ "$NVIDIA_VISIBLE_DEVICES" == "all" ] || [ -z "$NVIDIA_VISIBLE_DEVICES" ]; then
    export GPU_SELECT="$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)"
    # Get first GPU device out of the visible devices in other situations
else
    export GPU_SELECT="$(nvidia-smi --id=$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1) --query-gpu=uuid --format=csv,noheader | head -n1)"
    if [ -z "$GPU_SELECT" ]; then
        export GPU_SELECT="$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)"
    fi
fi

if [ -z "$GPU_SELECT" ]; then
    echo "No NVIDIA GPUs detected or nvidia-container-toolkit not configured. Exiting."
    exit 1
fi

# Setting `VIDEO_PORT` to none disables RANDR/XRANDR, do not set this if using datacenter GPUs
if [ "$(echo ${VIDEO_PORT} | tr '[:upper:]' '[:lower:]')" = "none" ]; then
  export CONNECTED_MONITOR="--use-display-device=None"
# The X server is otherwise deliberately set to a specific video port despite not being plugged to enable RANDR/XRANDR, monitor will display the screen if plugged to the specific port
else
  export CONNECTED_MONITOR="--connected-monitor=${VIDEO_PORT}"
fi

# Bus ID from nvidia-smi is in hexadecimal format and should be converted to decimal format (including the domain) which Xorg understands, required because nvidia-xconfig doesn't work as intended in a container
HEX_ID="$(nvidia-smi --query-gpu=pci.bus_id --id="$GPU_SELECT" --format=csv,noheader | head -n1)"
IFS=":." ARR_ID=($HEX_ID)
unset IFS
BUS_ID="PCI:$((16#${ARR_ID[1]}))@$((16#${ARR_ID[0]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))"

# A custom modeline should be generated because there is no monitor to fetch this information normally
export MODELINE="$(cvt -r "${DISPLAY_SIZEW}" "${DISPLAY_SIZEH}" "${DISPLAY_REFRESH}" | sed -n 2p)"

# Generate /etc/X11/xorg.conf with nvidia-xconfig
sudo nvidia-xconfig --virtual="${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" --depth="$DISPLAY_CDEPTH" --mode="$(echo "$MODELINE" | awk '{print $2}' | tr -d '\"')" --allow-empty-initial-configuration --no-probe-all-gpus --busid="$BUS_ID" --include-implicit-metamodes --mode-debug --no-sli --no-base-mosaic --only-one-x-screen ${CONNECTED_MONITOR}

# Guarantee that the X server starts without a monitor by adding more options to the configuration
sudo sed -i '/Driver\s\+"nvidia"/a\    Option         "ModeValidation" "NoMaxPClkCheck,NoEdidMaxPClkCheck,NoMaxSizeCheck,NoHorizSyncCheck,NoVertRefreshCheck,NoVirtualSizeCheck,NoExtendedGpuCapabilitiesCheck,NoTotalSizeCheck,NoDualLinkDVICheck,NoDisplayPortBandwidthCheck,AllowNon3DVisionModes,AllowNonHDMI3DModes,AllowNonEdidModes,NoEdidHDMI2Check,AllowDpInterlaced"' /etc/X11/xorg.conf
sudo sed -i '/Driver\s\+"nvidia"/a\    Option         "PrimaryGPU" "yes"' /etc/X11/xorg.conf

# Support external GPUs
sudo sed -i '/Driver\s\+"nvidia"/a\    Option         "AllowExternalGpus" "True"' /etc/X11/xorg.conf

# Add custom generated modeline to the configuration
sudo sed -i '/Section\s\+"Monitor"/a\    '"$MODELINE" /etc/X11/xorg.conf

# Prevent interference between GPUs, add this to the host or other containers running Xorg as well
echo -e "Section \"ServerFlags\"\n    Option         \"DontVTSwitch\" \"true\"\n    Option         \"AllowMouseOpenFail\" \"true\"\n    Option         \"AutoAddGPU\" \"false\"\nEndSection" | sudo tee -a /etc/X11/xorg.conf > /dev/null

sudo ln -snf /dev/ptmx /dev/tty7 || echo 'Failed to create /dev/tty7 device'
