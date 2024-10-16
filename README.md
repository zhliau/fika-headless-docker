# About
:new_moon_with_face: Run the FIKA dedicated client as a headless service, in a docker container! :new_moon_with_face:

- [Dedicated Client](#dedicated-client)
- [🧙 Features](#-features)
- [📦 Releases](#-releases)
- [🚤 Running](#-running)
    + [Requirements](#requirements)
    + [Steps](#steps)
    + [docker-compose](#docker-compose)
  * [Corter-Modsync support](#corter-modsync-support)
- [🌐 Environment variables](#-environment-variables)
  * [Required](#required)
  * [Optional](#optional)
  * [Debug](#debug)
- [🧰 Troubleshooting](#-troubleshooting)
    + [Container immediately exits](#container-immediately-exits)
    + [Stuck right after BepInEx preloader finished](#stuck-right-after-bepinex-preloader-finished)
    + [Crash with assertion in virtual.c](#crash-with-assertion-in-virtualc)
    + [Container stalls at wine: RLIMIT_NICE <= 20](#container-stalls-at-wine-rlimit_nice-is-20)
    + [My container memory usage keeps going up until I run out of memory](my-container-memory-usage-keeps-going-up-until-i-run-out-of-memory)
- [💻 Development](#-development)
    + [Building](#building)
    + [Using an Nvidia GPU in the container](#using-an-nvidia-gpu-in-the-container)

# Dedicated Client

## What is a Dedicated Client?

A dedicated client in the context of FIKA and SPT is essentially a separate instance of the game client that runs in a headless mode to host raids. It acts as a "silent player" that hosts the raid, allowing other players to join without one of them having to host the raid on their own machine.

- **Offloading Raid Hosting**: By using a dedicated client, the computational load of hosting a raid is offloaded from the player's machine to the dedicated client. This can improve performance for players, especially those with less powerful hardware.
- **Consistent Hosting**: Ensures that the raid hosting environment is consistent, as it runs on a dedicated server with stable resources.
- **Standardized Raid Settings**: The dedicated client allows for centralized control over raid settings such as AI behavior, difficulty, and spawning. This ensures a uniform experience for all players, as these settings are managed in one place.

## Pros
- **Performance**: Reduces the CPU and RAM load on the player's machine, potentially improving FPS and game performance.
- **Stability**: Provides a stable environment for hosting raids, reducing the risk of crashes or performance drops.
- **Scalability**: Allows for more players to join without impacting the host's performance.

## Cons
- **Resource Intensive**: Requires a server with significant resources (CPU, RAM, and storage) to run effectively.
- **Complex Setup**: Involves setting up and maintaining a separate server environment, which can be complex for those unfamiliar with Docker or server management.
- **Cost**: Running a dedicated server may incur additional costs, especially if using cloud services.

# 🧙 Features
- 🐎 Run Fika Dedicated client fully headless in docker container, with or without GPU on the docker host.
- 🔄 Supports [Corter-ModSync](https://github.com/c-orter/modsync/), to automatically keep dedicated client mods up to date
- 🔨 Automatic restart on raid end, to manage container memory usage
- 🚚 Automatic purging of EFT `Logs/` dir, to clear out large logfiles due to logspam
- 🍬 Optionally use Nvidia GPU when running the client, still completely headless without a real display

# 📦 Releases
The image build is triggered off git tags and hosted on ghcr. `latest` will always point to the latest version.
```
docker pull ghcr.io/zhliau/fika-headless-docker:latest
```

# 🚤 Running
I've only tested this on my linux hosts (Arch kernel 6.9.8 and Fedora 6.7.10).
This won't work on Windows because of permission issues with WSL2.
Probably will not work on ARM hosts either.

Tested with both SPT 3.8.3 and SPT 3.9.x and the associated Fika versions. 

### Requirements
- An SPT backend server running somewhere reachable by your docker host. Best if running on the same host.
  - You can use my other docker image for running SPT server + Fika: [fika-spt-server-docker](https://github.com/zhliau/fika-spt-server-docker)
- A host with a CPU capable of running EFT+SPT. This will be a disaster running on something like a Pi since the dedicated client is a full fledged client that will run all of the AI and raid logic.
- A directory on your host containing a **working copy of the FIKA SPT Client**.
  - This is the folder including the `BepInEx` folder with all your plugins, and the `EscapeFromTarkov.exe` binary. You can copy your working install from wherever you normally run your Fika client.
- The `Fika.Dedicated.dll` plugin file in the FIKA SPT Client's `BepInEx/plugins` folder.


### Steps

1. **Prepare a Dedicated Client Installation**

   - **Copy SPT Installation**: Locate your existing SPT installation folder (where you play SPTarkov + Fika) and create a copy of it in another location. This will serve as the dedicated client's installation. For example, if your SPT install is at `D:\Games\SPT3.9`, copy it to `D:\Games\SPT3.9Dedicated`. Or install a fresh SPT + Fika installation in a different directory.

2. **Install Fika Dedicated Client Plugin**

   - **Download Fika Dedicated Plugin**: Download the `Fika.Dedicated.dll` plugin from the [Fika Dedicated Releases](https://github.com/project-fika/Fika-Dedicated/releases).

   - **Install the Plugin**: Place the `Fika.Dedicated.dll` plugin into the dedicated client's `BepInEx/plugins` folder.

   - **Ensure Fika Core Plugin is Installed**: Verify that the `Fika.Core.dll` plugin is also present in the dedicated client's `BepInEx/plugins` folder.

3. **Generate the Dedicated Client Profile and Launch Script**

   - **Stop the SPT Server**: If your SPT + Fika server is running, close it.

   - **Edit Fika Configuration**: Open the `fika.jsonc` file located at `<SPT server folder>/user/mods/fika-server/assets/configs/fika.jsonc` in a text editor.

     - Find the `"dedicated"` section and set `"amount"` to `1`:

       ```jsonc
       "dedicated": {
           "profiles": {
               "amount": 1 // the amount of dedicated profiles to generate automatically
           },
           "scripts": {
               "generate": true, // generate the launch script
               "forceIp": "" // set to your dedicated client's IP address if needed
           }
       }
       ```

   - **Start the SPT Server**: Launch the SPT + Fika server (e.g. `SPT.Server.exe` or `fika-spt-server-docker` container) and wait until it fully loads. It should generate the dedicated client profile and launch script. Look for a message like `Created 1 dedicated client profiles!` in the server logs.

   - **Retrieve Profile ID**: The profile ID is the filename (excluding the `.json` extension) of the profile generated in the server's `user/profiles` directory. For example, if the profile is named `670c0b1a00014a7192a983f9.json`, the profile ID is `670c0b1a00014a7192a983f9`.

4. **Configure the Dedicated Client**

   - **Edit Fika Core Configuration**: Open the `com.fika.core.cfg` file located in the dedicated client's `BepInEx/config/` directory.

     - Update values for `Force Bind IP` and/or `Force IP`. It might be sufficient to set `Force Bind IP` to `Disabled`, and to set `Force IP` to the IP of the host interface.
       If you are running a VPN, then this is your VPN IP.

       ```
       ## Force Bind IP
       # Set to Disabled
       Force Bind IP = Disabled

       ## Force IP
       # Set to the IP address of your host interface (e.g., your LAN IP or VPN IP)
       Force IP = your.host.interface.ip
       ```

5. **Run the Docker Image**

   - **Mount the Fika Client Directory**: Ensure that your dedicated client installation directory is mounted to `/opt/tarkov` in the container. If you are running the dedicated client on a server, you will need to copy and transfer the dedicated client installation to the server (~40GB).

   - **Set Environment Variables**: When running the docker image, set the following environment variables:

     - `PROFILE_ID` to the profile ID obtained in step 3.

     - `SERVER_URL` to your server's URL or IP address.

     - `SERVER_PORT` to your server's port (usually `6969`).

     - Optionally, set `USE_MODSYNC` to `true` if you are using [Corter-ModSync](https://github.com/c-orter/modsync/) for plugin synchronization.

   - **Run the Docker Container**:

     ```shell
     docker run --name fika_dedicated \
       -v /path/to/fika:/opt/tarkov \
       -e PROFILE_ID=blah \
       -e SERVER_URL=your.spt.server.ip \
       -e SERVER_PORT=6969 \
       -p 25565:25565/udp \
       ghcr.io/zhliau/fika-headless-docker:latest
     ```

     With docker-compose file:
     ```yaml
     services:
       fika_dedicated:
         image: ghcr.io/zhliau/fika-headless-docker:latest
         container_name: fika_dedi
         volumes:
           - /host/path/to/fika:/opt/tarkov
         environment:
           - PROFILE_ID=adadadadadadaadadadad
           - SERVER_URL=your.spt.server.ip
           - SERVER_PORT=6969
           - USE_MODSYNC=true # If you want to use modsync on this dedicated client
         ports:
           - 25565:25565/udp
     ```

     If you are running the SPT server in docker, you can make use of docker-compose's network DNS to connect the dedicated client to the SPT server:

     ```yaml
     services:
       fika:
         # See https://github.com/zhliau/fika-spt-server-docker
         image: ghcr.io/zhliau/fika-spt-server-docker:latest
         volumes:
           - /host/path/to/serverfiles:/opt/server
         ports:
           - 6969:6969
       fika_dedicated:
         image: ghcr.io/zhliau/fika-headless-docker:latest
         # ...
         environment:
           # ...
           # Use service DNS name instead of IP
           - SERVER_URL=fika
           - SERVER_PORT=6969
         # ...
     ```

6. **Verify the Dedicated Client is Running**

   - **Check Server Logs**: Look for messages in the server logs indicating that the dedicated client has connected. Note that this may take a few minutes to happen (~5 minutes).

   - **Start a Raid Using Dedicated Host**:

     - Launch your SPT + Fika client, log in, and go to the raid selection screen.

     - Click on `Host Raid` and ensure that the `Use Dedicated Host` option is available (not greyed out).

     - Proceed to host a raid using the dedicated client.

## Corter-Modsync support
This image supports the unique plugin updater process that [Corter-ModSync](https://github.com/c-orter/modsync/) employs to update client plugins.
To enable support:
- Copy the `Fika.Dedicated.dll` plugin file into the **server's BepInEx directory** (the directory that modsync treats as the source of truth).
- **(IMPORTANT)** Ensure you have `"BepInEx/plugins/Fika.Dedicated.dll"` in the `commonModExclusions` list in the ModSync server configuration. It should already be there by default.
  This is to ensure that ModSync does not push the Dedicated plugin to clients nor delete it from the container, especially if you are enforcing the `BepInEx/plugins` path on all connecting clients
- Set the `USE_MODSYNC` env var to `true` when starting the container.

The start script will then:
- Start Xvfb in the background to make it available to all running container processes
- Anticipate that ModSync may close the dedicated client for an update
- On client plugin update, the script will restart the dedicated client.

> [!NOTE]
> Enabling `USE_MODSYNC` does NOT mean that the dedicated client will periodically restart to check for updates to plugins. If you wish to do this, you must build it
> via a periodic restarter script or a cron job. You can mount the docker socket into a `docker:cli` image and run a simple bash while loop or something.
> See the example docker-compose.yml in this repo for details

# 🌐 Environment variables
## Required

| Env var       | Description                                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `PROFILE_ID`  | ProfileID of the dedicated client you created in step 1                                                                                    |
| `SERVER_URL`  | Server URL, or the name of the service that runs the Fika server if you have it in the same docker-compose stack                           |
| `SERVER_PORT` | Server port, usually `6969`                                                                                                                |

## Optional

| Env var                        | Description                                                                                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `USE_DGPU`                     | If set to `true`, enable passing a GPU resource into the container with `nvidia-container-toolkit`. Make sure you have the required dependencies installed for your host |
| `DISABLE_NODYNAMICAI`          | If set to `true`, removes the `-noDynamicAI` parameter when starting the client, allowing the use of Fika's dynamic AI feature. Can help with dedicated client performance if you notice server FPS dropping below 30 |
| `USE_MODSYNC`                  | If set to `true`, enables support for Corter-ModSync 0.8.1+ and the external updater. On container start, the dedicated client will close and start the updater the modsync plugin detects changes. On completion, the script will start the dedicated client up again |
| `ENABLE_LOG_PURGE`             | If set to `true`, automatically purge the EFT `Logs/` directory every 00:00 UTC, to clear out large logfiles due to logspam. |
| `AUTO_RESTART_ON_RAID_END`     | If set to `true`, auto restart the client on raid end, freeing all memory that isn't cleared properly on raid end |

## Debug

| Env var             | Description                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `USE_GRAPHICS`      | If set to `true`, disables the `-nographics` parameter when starting the dedicated client. This will significantly increase resource usage.                                                                           |
| `DISABLE_BATCHMODE` | If set to `true`, disable the `-batchmode` parameter when starting the client. This will significantly increase resource usage.                                                                                       |
| `XVFB_DEBUG`        | If set to `true`, enables debug output for xvfb (the virtual framebuffer)                                                                                                                                             |

# 🧰 Troubleshooting
### Container immediately exits
Crashing with stacktrace in container, permissions errors, wine unable to find EscapeFromTarkov.exe, or wine throwing a page fault on read access to 0000000000000000 exception?
- If you are using Corter-ModSync to keep plugin files up to date, make sure you set the `USE_MODSYNC` env var to `true` or the plugin updater will not be able to run properly and the container will keep exiting!
- Make sure you do not have an invalid plugin in the Dedicated client's plugins folder. You can see the list of invalid plugins [here](https://github.com/project-fika/Fika-Dedicated/blob/fa420874753e6d0adf3e31f8404fa855855cd339/Fika.Dedicated/FikaDedicatedPlugin.cs#L179)
- Double check that you have both the `Fika.Core.dll` and `Fika.Dedicated.dll` plugins in the client's `BepInEx/plugins` folder! The game will crash in the container if you don't have both plugins!
- Check your docker logs output. Maybe you haven't mounted your FIKA client directory properly? Verify the contents of the Fika Client directory to make sure all expected files are there. You must mount a working copy of the Fika client to `/opt/tarkov`.
- Double check that your file permissions for the Fika client directory and its contents are correct. The container runs as the user `root`, so it should be able to read any mounted files as long as you don't have anything unusual with your file permissions.
- If you have SELinux enabled on the host, the container may not be able to read the mounted directories unless you provide the :z option to re-label the mount with the correct SELinux context.
  Be VERY careful with this option! I will not be responsible for anything that happens if you choose to do this.
- Make sure your Fika client files have the winhttp.dll in the root folder. This is required for any plugins (even SPT) to run.

### Stuck right after BepInEx preloader finished
```
fika_dedi  | [Message:   BepInEx] Preloader finished
fika_dedi  | (Filename: C:\buildslave\unity\build\Runtime/Export/Debug/Debug.bindings.h Line: 39)
fika_dedi  |
fika_dedi  | Fallback handler could not load library Z:/opt/tarkov/EscapeFromTarkov_Data/Mono/data-00007D86E24EA790.dll
```
- Double check your server is reachable at whatever you set `SERVER_URL` to. If the client can't reach the backend, it tends to hang here.
- If you are using ProxMox to spin up a VM to run this image, make sure nested virtualization is enabled.
- Double check that you have both the `Fika.Core.dll` and `Fika.Dedicated.dll` plugins in the client's `BepInEx/plugins` folder! The game will crash in the container if you don't have both plugins!
- Ensure your server contains a profile json file with filename matching the `PROFILE_ID` you provided to the container

### Crash with assertion in virtual.c
```
../src-wine/dlls/ntdll/unix/virtual.c:1907: create_view: Assertion `!((UINT_PTR)base & page_mask)' failed.
```
If the dedicated client container crashes with this error, this usually means your max memory map count is too low.
- Set the value higher and then try restarting the dedicated client
  
  `sudo sysctl -w vm.max_map_count=2147483642`
  
  Make this persist between reboots by creating a file `/etc/sysctl.d/80-vm-mmax.conf` with the following contents:
  ```
  vm.max_map_count = 2147483642
  ```

### Container stalls at wine: RLIMIT_NICE is <=20
This happens sometimes on first boot or when the container is force-recreated e.g. by `docker-compose up --force-recreate`. I have no idea why it happens, but to solve it you can
- Just wait. Almost exactly 5 minutes after this line is emitted, the client will resume starting normally
- Restart the container with `docker restart` or `docker-compose restart`. This will force the client to start up immediately.

### My container memory usage keeps going up until I run out of memory
- Try setting the `AUTO_RESTART_ON_RAID_END` env var to `true`, to have the client restart itself after each raid is completed and all players have extracted.
  This should effectively reset container memory usage back to the ~3Gb required on first boot, after each raid.
- EFT is extremely memory hungry, if you are running out of memory while in raid, try to remove some mods that may be memory intensive to see if memory usage improves.
- There may be no better solution than to simply add more RAM to the docker host.

# 💻 Development
### Building
Run the `build` script, optionally setting a `VERSION` env var to tag the image. The image is tagged `fika-dedicated:latest`, or whatever version is provided in the env var.
```
# image tagged as fika-dedicated:0.1
$ VERSION=0.1 ./build
```

### Using an Nvidia GPU in the container
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
  fika_dedicated:
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
