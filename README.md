# About
:new_moon_with_face: Run the FIKA headless client in a docker container! :new_moon_with_face:

- [🧙 Features](#-features)
- [👻 Headless Client](#-headless-client)
- [📦 Releases](#-releases)
- [🚤 Running](#-running)
    + [Corter-Modsync support](#corter-modsync-support)
    + [Wine Synchronization methods](#wine-synchronization-methods)
- [🌐 Environment variables](#-environment-variables)
  * [Required](#required)
  * [Optional](#optional)
  * [Debug](#debug)
- [🧰 Troubleshooting](#-troubleshooting)
- [💻 Development](#-development)
    + [Building](#building)
    + [Using an Nvidia GPU in the container](#using-an-nvidia-gpu-in-the-container)

# 🧙 Features
- 🐎 Run Fika Headless client without display server in docker container, with or without GPU.
- 🔄 Supports [Corter-ModSync](https://github.com/c-orter/modsync/), to automatically keep headless client mods up to date
- 🔨 Automatic restart on raid end, to manage container memory usage
- 🚚 Automatic purging of EFT `Logs/` dir, to clear out large logfiles due to logspam
- 🍬 Optionally use Nvidia GPU when running the client, still completely headless without a real display
- 🧪 Tested and works on SPT 3.9.x, 3.10.x, 3.11.x
- 🦢 Pelican support - just follow the Pelican instructions in the installation steps.

# 👻 Headless Client

## What is a Headless Client?

The Fika headless client is a separate instance of the game client that runs without a display. It acts as a "silent player" that hosts the raid, allowing other players to join raids without one of them having to host the raid on their own machine.

- **Offloading Raid Hosting**: By using a headless client, the computational load of hosting a raid is offloaded from the players' machines to the headless client. This can improve performance for players, especially those with less powerful hardware.
- **Consistent Hosting**: Ensures that raids run with consistent performance, as raids are hosted on a dedicated machine.
- **Standardized Raid Settings**: The headless client allows for centralized control over raid settings such as AI behavior, difficulty, and spawning. This ensures a uniform experience for all players, as these settings are managed in one place.

## Why should I use a headless client?
- **Performance**: Reduces the CPU and RAM load on the player's machine, potentially improving FPS and game performance.
- **Stability**: Provides a stable environment for hosting raids, reducing the risk of crashes or performance drops. In the event the headless client crashes, all players can still extract from the raid and save progress.
- **Scalability**: Allows for more players to join without impacting the host's performance.

# 📦 Releases
The image build is triggered off git tags and hosted on ghcr. `latest` will always point to the latest version.
```
docker pull ghcr.io/zhliau/fika-headless-docker:latest
```

# 🚤 Running
> [!NOTE]
> This image is confirmed to work on Unraid, Proxmox, but there may be issues with the client stalling.
>
> This image **will** work on Pelican assuming you use the Pelican egg file provided in this repo.
>
> This image will **not** run on WSL2 because of permissions issues.
>
> This image will **not** run on ARM hosts, since it uses wine built on x86.

> [!WARNING]
> If you are running this image on SPT version < 3.11, make sure to disable HTTPS by setting the environment variable `HTTPS` to `false`!

## Prerequisites
- An SPT backend server running somewhere reachable by your docker host. Best if running on the same host.
  - You can use my other docker image for running SPT server + Fika: [fika-spt-server-docker](https://github.com/zhliau/fika-spt-server-docker)
- A host with a CPU capable of running EFT+SPT Client (**the actual game itself**). This will be a disaster running on something underpowered like a Pi since the headless client will host the raid and run all of the AI and raid logic.
- A directory on your docker host containing a **working copy of the FIKA SPT Client**.
  - This is the folder including the `BepInEx` folder with all your plugins, and the `EscapeFromTarkov.exe` binary. This copy must have been run at least once to be considered working. You can copy your working install from wherever you normally run your Fika client.
- The `Fika.Headless.dll` plugin file (or `Fika.Dedicated.dll` if running SPT version < 3.11.0) in the FIKA SPT Client's `BepInEx/plugins` folder.


## Steps
### 1. **Prepare a Headless Client Installation**

   - **Copy SPT Installation**: Locate your existing SPT installation folder (the files you use to play EFT + SPTarkov + Fika) and copy it to the machine you will use to run this image. This will serve as the headless client's installation.
   - **Using Pelican?**: If you're using Pelican, Copy your existing SPT installation folder to a new folder on the same computer. We'll upload the files to the target machine in step #5.

### 2. **Install Fika Headless Client Plugin**

   - **Download Fika Headless Plugin**: Download the `Fika.Headless.dll` plugin file (or `Fika.Dedicated.dll` if running SPT version < 3.11.0) from the [Fika Dedicated Releases](https://github.com/project-fika/Fika-Dedicated/releases).

   - **Install the Plugin**: Place the plugin file into the headless client's `BepInEx/plugins` folder.

   - **Ensure Fika Core Plugin is Installed**: Verify that the `Fika.Core.dll` plugin is also present in the headless client's `BepInEx/plugins` folder.

### 3. **Generate the Headless Client Profile and Launch Script**

   - **Stop the SPT Server**: If your SPT + Fika server is running, close it.

   - **Edit Fika Configuration**: Open the `fika.jsonc` file located at `<SPT server folder>/user/mods/fika-server/assets/configs/fika.jsonc` in a text editor.

     - Find the `headless` section (or `dedicated` if SPT version < 3.11) and set `"amount"` to `1`:

       ```jsonc
       "headless": {
           "profiles": {
               "amount": 1
           },
           // ...
       }
       ```

   - **Start the SPT Server**: Launch the SPT + Fika server (e.g. `SPT.Server.exe` or `fika-spt-server-docker` container) and wait until it fully loads. It should generate the headless client profile and launch script. Look for a message like `Created 1 headless client profiles!` in the server logs.

   - **Retrieve Profile ID**: The newly generated profile will have a username starting with `headless_`. The profile ID is the filename (excluding the `.json` extension) of the profile generated in the server's `user/profiles` directory. For example, if the profile is named `670c0b1a00014a7192a983f9.json`, the profile ID is `670c0b1a00014a7192a983f9`.

### 4. **Configure the Headless Client**

   - **Edit Fika Core Configuration**: Open the `com.fika.core.cfg` file located in the headless client's `BepInEx/config/` directory.

     - Update values for `Force Bind IP` and/or `Force IP`.
       - Set `Force Bind IP` to `Disabled`.
       - If your users are connecting via port-forwarding, set `Force IP` to blank or your host's Public/WAN IP.
       - If your users are connecting via VPN, set `Force IP` to your docker host's VPN IP.

       ```
       ## Force Bind IP
       # Set to Disabled
       Force Bind IP = Disabled

       ## Force IP
       # Set blank, or to the IP address of your host interface (e.g., your WAN IP or VPN IP)
       Force IP = 
       ```

### 5. **Run the Docker Image**

   - ### Using Pelican? Skip to [Running with Pelican](#5a-running-with-pelican)

   - **Mount the Fika Client Directory**: When running the docker image, ensure that your headless client installation directory (e.g. `/host/path/to/fika`) is volume-mounted to the directory `/opt/tarkov` in the container. You can do this with the `-v` option in docker, or the `volume` directive in your docker-compose yaml file.

   - **Set Environment Variables**: When running the docker image, set the following environment variables:

     - `PROFILE_ID` to the profile ID obtained in step 3.

     - `SERVER_URL` to your server's URL or IP address.

     - `SERVER_PORT` to your server's port (usually `6969`).

   - **Run the Docker Container**:

     ```shell
     docker run --name fika_headless \
       -v /host/path/to/fika:/opt/tarkov \
       -e PROFILE_ID=blah \
       -e SERVER_URL=your.spt.server.ip \
       -e SERVER_PORT=6969 \
       -p 25565:25565/udp \
       ghcr.io/zhliau/fika-headless-docker:latest
     ```

     With docker-compose file:
     ```yaml
     services:
       fika_headless:
         image: ghcr.io/zhliau/fika-headless-docker:latest
         volumes:
           - /host/path/to/fika:/opt/tarkov
         environment:
           - PROFILE_ID=deadbeeffeed
           - SERVER_URL=your.spt.server.ip
           - SERVER_PORT=6969
         ports:
           - 25565:25565/udp
     ```

     If you are running the SPT server as a service in the same docker-compose stack, you can make use of docker-compose's network DNS to resolve the SPT server from the headless client:

     ```yaml
     services:
       fika:
         # See https://github.com/zhliau/fika-spt-server-docker
         image: ghcr.io/zhliau/fika-spt-server-docker:latest
         volumes:
           - /host/path/to/serverfiles:/opt/server
         ports:
           - 6969:6969
       fika_headless:
         image: ghcr.io/zhliau/fika-headless-docker:latest
         # ...
         environment:
           # ...
           # Use service DNS name instead of IP
           - SERVER_URL=fika
           - SERVER_PORT=6969
         # ...
     ```

### 5a. **Running with Pelican**

   - ### Not Using Pelican? Skip to [Verify the Headless Client is Running](#6-verify-the-headless-client-is-running)

   - Warning on Pelican usage: Certain features of this docker container may not work on Pelican. Specifically the USE_DGPU option may not function as intended as Pelican doesn't provide us a way to pass the host's nvidia device to the container. Please forgo Pelican and see [Run the Docker Image](#5-run-the-docker-image) if you're looking for this functionality.

   - **Import the provided Pelican egg**:

     - Navigate to your Pelican panel's admin area, navigate to "Eggs" on the side panel and click "Import".
     - Right click and Copy the following URL, Paste it into the "URL" tab of the import box and click submit: [Pelican Egg](/egg-s-p-t-fika-headless-client.json) 

  - **Creating the Server**:

     - Navigate to "Servers" on the side panel and click "New Server"
     - Enter the name of your server, and select or create an IP Allocation that uses port 25565. If you'd like to use a port other than 25565, this is where to do so. This is **not** the port of your SPT Server.

  - **Set Environment Variables**: On the next page, you'll have a list of Environment variables to set, the following are **required**:

     - `PROFILE ID` to the profile ID obtained in step 3.

     - `SERVER URL` to your server's URL or IP address.

     - `SERVER PORT` to your SPT server's port (usually `6969`).

     - If you're running an SPT Version < 3.11.0, make sure the "HTTPS" Variable is set to `false`, else it must be set to `true`.

  - **Environment Configuration**: This is where you'll assign Resource limits to CPU, Memory and Disk space.

     - I recommend leaving the CPU Unlimited.
     - You will likely need a _minimum_ of 16gb of RAM (To allocate to the server, meaning the host machine should probably have more).
     - I recommend setting `Swap Memory` to `Unlimited` 
     - _At least_ 60GB of disk space is necessary for the full installation of this container. I recommend having more available to prevent any future issues.
     - Allocations and Databases aren't necessary for this installation, backups can be decided at your discretion
     - Don't alter the docker settings.

  - **Installation and EFT File upload**: Once your server has been created the installation script will create a directory called `tarkov`. 

     - Connect to your Pelican server via the FTP Credentials provided via the Pelican client area under `Settings`
     - Upload your Headless client installation you created in Step #1 to the `/tarkov` directory in the FTP Server. Your file structure should look like the following once your upload is complete:
     ```
     └──📁 tarkov/  
       ├── 📁 BepInEx/  
       ├── 📁 EscapeFromTarkov_Data/  
       ├── 📁 Logs/  
       ├── 📁 .../  
       ├── 📁 SPT_Data/  
       ├── 📁 user/  
       ├── 🔫 EscapeFromTarkov.exe  
       └── 🗃️ ... etc.
     ```

  - **Start the Server**: You should now be ready to start the server. The first boot will take awhile (~5-10 minutes+, depending on internet and computer speed) as it needs to download and setup the docker container.
    - Wait until the Pelican server status has changed from Starting to Started.


### 6. **Verify the Headless Client is Running**

   - **Check Server Logs**: Look for messages in the SPT Server logs indicating that the headless client has connected. Note that this may take a few minutes to happen (~5 minutes).

   - **Start a Raid Using Headless Client**:

     - Launch your SPT + Fika client, log in, and go to the raid selection screen.

     - Click on `Host Raid` and ensure that the `Use Headless Host` checkbox is available (not greyed out).

     - Check the box to host a raid using the headless client.


## Corter-Modsync support
See [this wiki article](https://github.com/zhliau/fika-headless-docker/wiki/Corter%E2%80%90Modsync-support) for information on how to enable Corter-Modsync support.

## Wine Synchronization Methods
See [this wiki page](https://github.com/zhliau/fika-headless-docker/wiki/Wine-synchronization-methods) on the supported winesync methods and how to enable them.

# 🌐 Environment variables
## Required

| Env var       | Description                                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `PROFILE_ID`  | ProfileID of the headless profile to start the client with                                                                                 |
| `SERVER_URL`  | Server URL, or the name of the service that runs the Fika server if you have it in the same docker-compose stack                           |
| `SERVER_PORT` | Server port, usually `6969`                                                                                                                |

## Optional

| Env var                        | Description                                                                                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `HTTPS`                        | If set to `true`, use https when constructing the backend connection string. This defaults to `true` but can be set to `false` if playing on SPT versions that did not support https (< 3.11) |
| `DISABLE_NODYNAMICAI`          | If set to `true`, removes the `-noDynamicAI` parameter when starting the client, allowing the use of Fika's dynamic AI feature. Can help with headless client performance if you notice server FPS dropping below 30 |
| `USE_MODSYNC`                  | If set to `true`, enables support for Corter-ModSync 0.8.1+ and the external updater. On container start, the headless client will close and start the updater the modsync plugin detects changes. On completion, the script will start the headless client up again |
| `ENABLE_LOG_PURGE`             | If set to `true`, automatically purge the EFT `Logs/` directory every 00:00 UTC, to clear out large logfiles due to logspam. |
| `AUTO_RESTART_ON_RAID_END`     | If set to `true`, auto restart the client on raid end, freeing all memory that isn't cleared properly on raid end |
| `ESYNC`                        | If set to `true`, enable wine esync, to use eventfd based synchronization instead of wineserver. This can improve client performance. Check compatibility by `ulimit -Hn`. If this value is less than `524288`, you need to increase your system's process file descriptor limit. See this [troubleshooting tip](https://github.com/zhliau/fika-headless-docker/wiki/%F0%9F%A7%B0-Troubleshooting#im-using-esync-but-my-client-crashes). |
| `FSYNC`                        | If set to `true`, enable wine fsync, to use futex based synchronization instead of wineserver. This can dramatically improve client performance. Takes precedence over ESYNC. Requires linux kernel version >= 5.16. Check compatibility via kernel syscall availability with `cat /proc/kallsyms | grep futex_waitv`. |
| `NTSYNC`                       | If set to `true`, enable wine ntsync, to use a wine binary compiled with support for kernel level implementation of Windows NT synchronization primitives, the latest and potentially highest performing synchronization method. This can dramatically improve client performance. Takes precedence over FSYNC or ESYNC. Requires ntsync support in your host kernel. See [this wiki page](https://github.com/zhliau/fika-headless-docker/wiki/Wine-synchronization-methods) for details |

## Debug

| Env var                    | Description                                                                                                                                                                                         |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `USE_DGPU`                 | If set to `true`, enable passing a GPU resource into the container with `nvidia-container-toolkit`. Additional setup and dependencies are required. Please see [Using an Nvidia GPU in the container](#using-an-nvidia-gpu-in-the-container) for details |
| `USE_GRAPHICS`             | If set to `true`, disables the `-nographics` parameter when starting the headless client. |
| `DISABLE_BATCHMODE`        | If set to `true`, disable the `-batchmode` parameter when starting the client. This will significantly increase resource usage.                                                                                       |
| `XVFB_DEBUG`               | If set to `true`, enables debug output for xvfb (the virtual framebuffer)                                                                                                                                             |
| `SAVE_LOG_ON_EXIT`         | If set to `true`, save a copy of the BepInEx `LogOutput.log` as `LogOutput-$timestamp.log` on client exit to preserve logs from previous client runs, since this file is truncated each time the client starts |

# 🧰 Troubleshooting
See [this wiki page](https://github.com/zhliau/fika-headless-docker/wiki/%F0%9F%A7%B0-Troubleshooting) for common problems and solutions.

# 💻 Development
### Building
Run the `build` script, optionally setting a `VERSION` env var to tag the image. The image is tagged `fika-dedicated:latest`, or whatever version is provided in the env var.
```
# image tagged as fika-dedicated:0.1
$ VERSION=0.1 ./build
```

### Using an Nvidia GPU in the container
> [!WARNING]
> This is a legacy option and is not recommended for most use cases, as it has several downsides including
> increased resource usage, for potentially negligible client performance gain

If you want to pass in your host Nvidia GPU, make sure you have the following:
- set the env var `USE_DGPU=true` in the container
- set the env var `USE_GRAPHICS=true` to disable headless mode
- `nvidia-container-toolkit` installed on your host
- set the `deploy` section in compose.
- No X server running on host
```yaml
services:
  fika:
    # My own SPT image but you can use any other
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    # ...
  fika_headless:
    image: ghcr.io/zhliau/fika-headless-docker:latest
    container_name: fika_ded
    volumes:
      - /host/path/to/fika:/opt/tarkov
    environment:
      - PROFILE_ID=adadadadadadaadadadad
      - SERVER_URL=fika
      - SERVER_PORT=6969
      # Set USE_DGPU to enable installation of nvidia drivers in container and start Xorg server on virtual tty
      - USE_DGPU=true
      # Do not run headless
      - USE_GRAPHICS=true
    ports:
      - 25565:25565/udp
    # Specify nvidia device to pass to the container
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```
