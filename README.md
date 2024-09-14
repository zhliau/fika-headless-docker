# About
:new_moon_with_face: Run the FIKA dedicated client as a headless service, in a docker container! :new_moon_with_face:

:star: NEW: With :arrows_counterclockwise: [Corter-ModSync support](#corter-modsync-support) :arrows_counterclockwise:!

- [Releases](#releases)
- [Running](#running)
    + [Requirements](#requirements)
    + [Steps](#steps)
    + [docker-compose](#docker-compose)
  * [Corter-Modsync support](#corter-modsync-support)
- [Environment variables](#environment-variables)
  * [Required](#required)
  * [Optional](#optional)
  * [Debug](#debug)
- [Troubleshooting](#troubleshooting)
    + [Container immediately exits](#container-immediately-exits)
    + [Stuck right after BepInEx preloader finished](#stuck-right-after-bepinex-preloader-finished)
- [Development](#development)
    + [Building](#building)
    + [Using an Nvidia GPU in the container](#using-an-nvidia-gpu-in-the-container)

# Releases
The image build is triggered off commits to master and hosted on ghcr.
```
docker pull ghcr.io/zhliau/fika-headless-docker:master
```

# Running
I've only tested this on my linux hosts (Arch kernel 6.9.8 and Fedora 6.7.10).
This won't work on Windows because of permission issues with WSL2.
Probably will not work on ARM hosts either.

Tested with both SPT 3.8.3 and SPT 3.9.x and the associated Fika versions. 

### Requirements
- An SPT backend server running somewhere reachable by your docker host. Best if running on the same host.
- A host with a CPU capable of running EFT+SPT. This will be a disaster running on something like a Pi since the dedicated client is a full fledged client that will run all of the AI and raid logic.
- A directory on your host containing a **working copy of the FIKA SPT Client**.
  - This is the folder including the `BepInEx` folder with all your plugins, and the `EscapeFromTarkov.exe` binary. You can copy your working install from wherever you normally run your Fika client.
- The `Fika.Dedicated.dll` plugin file in the FIKA SPT Client's `BepInEx/plugins` folder.

### Steps
1. Create a profile that the dedicated client will login as. Copy its profileID and set it aside.
   - If you are on Fika for SPT 3.9.x, the server will generate this profie for you as long as you set the `dedicated > profiles > amount` option to some value greater than 0 in the server config.
   - You can find the profiles in the server `user/profiles` directory. The profileID is the filename of the profile, excluding the `.json` extension
2. Make sure your `Force Bind IP` and `Force IP` values in the `BepInEx/config/com.fika.core.cfg` config file on the dedicated client are set correctly.
   I found it sufficient to set `Force Bind IP` to `Disabled`, and to set `Force IP` to the IP of my host interface. If you are running a VPN, this is your VPN IP.
3. Ensure you have the `Fika.Dedicated.dll` plugin file in the dedicated client's plugins folder `BepInEx/plugins`.
5. Run the docker image, making sure you have the following configured:
    - Fika Client directory mounted to `/opt/tarkov` in the container.
    - `PROFILE_ID` env var set to the profile you created in step 1
    - `SERVER_URL` env var set to your server URL
    - `SERVER_PORT` env var set to your server's port
    - `USE_MODSYNC` env var set to `true` if you wish to use the excellent [Corter-ModSync](https://github.com/c-orter/modsync/) plugin on your dedicated client.

E.g
```shell
docker run --name fika_dedicated \
  -v /path/to/fika:/opt/tarkov \
  -e PROFILE_ID=blah \
  -e SERVER_URL=your.spt.server.ip \
  -e SERVER_PORT=6969 \
  -p 25565:25565/udp \
  ghcr.io/zhliau/fika-headless-docker:master
```

### docker-compose
Or better yet use a docker-compose file
```yaml
services:
  fika_dedicated:
    image: ghcr.io/zhliau/fika-headless-docker:master
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

If you are running the SPT server in docker, you can make use of docker-compose's network DNS 
```yaml
services:
  fika:
    image: fikadockerimagehere:latest
  fika_dedicated:
    image: ghcr.io/zhliau/fika-headless-docker:master
    # ...
    environment:
      # ...
      # Use service DNS name instead of IP
      - SERVER_URL=fika
      - SERVER_PORT=6969
    # ...
```

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

# Environment variables
## Required

| Env var       | Description                                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `PROFILE_ID`  | ProfileID of the dedicated client you created in step 1                                                                                    |
| `SERVER_URL`  | Server URL, or the name of the service that runs the Fika server if you have it in the same docker-compose stack                           |
| `SERVER_PORT` | Server port, usually `6969`                                                                                                                |

## Optional

| Env var       | Description                                                                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `USE_DGPU`    | If set to `true`, enable passing a GPU resource into the container with `nvidia-container-toolkit`. Make sure you have the required dependencies installed for your host |
| `DISABLE_NODYNAMICAI`  | If set to `true`, removes the `-noDynamicAI` parameter when starting the client, allowing the use of Fika's dynamic AI feature. Can help with dedicated client performance if you notice server FPS dropping below 30 |
| `USE_MODSYNC`  | If set to `true`, enables support for Corter-ModSync 0.8.1+ and the external updater. On container start, the dedicated client will close and start the updater the modsync plugin detects changes. On completion, the script will start the dedicated client up again |

## Debug

| Env var             | Description                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `USE_GRAPHICS`      | If set to `true`, disables the `-nographics` parameter when starting the dedicated client. This will significantly increase resource usage.                                                                           |
| `DISABLE_BATCHMODE` | If set to `true`, disable the `-batchmode` parameter when starting the client. This will significantly increase resource usage.                                                                                       |
| `XVFB_DEBUG`        | If set to `true`, enables debug output for xvfb (the virtual framebuffer)                                                                                                                                             |

# Troubleshooting
### Container immediately exits
Crashing with stacktrace in container, permissions errors, wine unable to find EscapeFromTarkov.exe, or wine throwing a page fault on read access to 0000000000000000 exception?
- If you are using Corter-ModSync to keep plugin files up to date, make sure you set the `USE_MODSYNC` env var to `true` or the plugin updater will not be able to run properly and the container will keep exiting!
- If you are using Amands.Graphics, remove it from the dedicated client's plugins. Sometimes, it causes an NPE on ending a raid and stops the client from returning to the main menu, preventing any new raids from starting.
- Double check that you have the `Fika.Dedicated.dll` file in the client's `BepInEx/plugins` folder! The game will crash in the container if you don't have this plugin.
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

# Development
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
    image: fikadockerimagehere:latest
  fika_dedicated:
    image: fika-dedicated:master
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
