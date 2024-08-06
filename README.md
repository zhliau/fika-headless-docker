# About
Run the FIKA dedicated client as a headless service, in a docker container!

# Releases
The image build is triggered off commits to master and hosted on ghcr.
```
docker pull ghcr.io/zhliau/fika-headless-docker:master
```

# Building
Run the `build` script. The image is tagged `fika-dedicated:0.1`

# Running
I've only tested this on my linux hosts (Arch kernel 6.9.8 and Fedora 6.7.10).
This won't work on Windows because of permission issues with WSL2.
Probably will not work on ARM hosts either.

Tested with both SPT 3.8.3 and SPT 3.9.3 and the associated Fika versions. 

### Requirements
- A host with a CPU capable of running EFT+SPT. This will be a disaster running on something like a Pi since the dedicated client is a full fledged client that will run all of the AI and raid logic.
- A directory on your host containing the **vanilla EFT files**.
  - This is the directory that contains your vanilla install of EFT, and contains the `EscapeFromTarkov_BE.exe` executable and `ConsistencyInfo` file.
- A directory on your host containing a **working copy of the FIKA SPT Client**.
  - This is the folder including the `BepInEx` folder with all your plugins, and the `EscapeFromTarkov.exe` binary. You can copy your working install from wherever you normally run your Fika client.
- The `Fika.Dedicated.dll` plugin file in the FIKA SPT Client's `BepInEx/plugins` folder.

### Running on SPT 3.8.3
You will need to build the `Fika.Dedicated.dll` plugin yourself from the Fika Plugin `headless-3.8.3` branch.

### Running on SPT 3.9.x
The team just released the official build of the dedicated plugin, so no need to build it yourself anymore!

## Steps
1. Create a profile that the dedicated client will login as. Copy its profileID and set it aside.
   If you are on Fika for SPT 3.9.x, the server will generate this profie for you as long as you set the `dedicated > profiles > amount` option to some value greater than 0 in the server config.
   You can find the profiles in the server `user/profiles` directory. The profileID is the filename of the profile, excluding the `.json` extension
2. Make sure your `Force Bind IP` and `Force IP` values in the `BepInEx/config/com.fika.core.cfg` config file on the dedicated client are set correctly.
   I found it sufficient to set `Force Bind IP` to `Disabled`, and to set `Force IP` to the IP of my host interface. If you are running a VPN, this is your VPN IP.
3. Ensure you have the `Fika.Dedicated.dll` plugin file in the dedicated client's plugins folder `BepInEx/plugins`.
4. If you use the excellent `modsync` plugin on your regular client, you might want to remove it from here and manually ensure all plugins are the same as your clients' in this BepInEx folder 
5. Run the docker image, making sure you have the following configured:
    - Vanilla EFT directory mounted to `/opt/live`.
    - Fika Client directory mounted to `/opt/tarkov` in the container.
    - `PROFILE_ID` env var set to the profile you created in step 1
    - `SERVER_URL` env var set to your server URL
    - `SERVER_PORT` env var set to your server's port
    - (No longer recommended) `USE_DGPU` env var set to `true`, to enable starting an X server in container in combination with `nvidia-container-toolkit` to use the host GPU resource
      *This will not work if you have an X server running on your host using your GPU already!*. This is due to Xorg server limitations.

E.g
```Shell
docker run --name fika_dedicated \
  -v /path/to/fika:/opt/tarkov \
  -v /path/to/vanilla:/opt/live \
  -e PROFILE_ID=blah \
  -e SERVER_URL=localhost \
  -e SERVER_PORT=6969 \
  -p 25565:25565/udp \
  ghcr.io/zhliau/fika-headless-docker:master
```

# docker-compose
Or better yet use a docker-compose file
```yaml
services:
  fika_dedicated:
    image: ghcr.io/zhliau/fika-headless-docker:master
    container_name: fika_dedi
    volumes:
      - /host/path/to/vanilla/:/opt/live
      - /host/path/to/fika:/opt/tarkov
    environment:
      - PROFILE_ID=adadadadadadaadadadad
      - SERVER_URL=localhost
      - SERVER_PORT=6969
    ports:
      - 25565:25565/udp
```

If you are running the SPT server in docker, you can make use of docker-compose's network DNS 
```yaml
services:
  fika:
    image: fikadockerimagehere:latest
  fika_dedicated:
    image: fika-dedicated:0.1
    container_name: fika_ded
    volumes:
      - /host/path/to/live/files:/opt/live
      - /host/path/to/fika:/opt/tarkov
    environment:
      - PROFILE_ID=adadadadadadaadadadad
      # Use service DNS name instead of IP
      - SERVER_URL=fika
      - SERVER_PORT=6969
    ports:
      - 25565:25565/udp
```

(**No longer recommended**)
If you want to pass in your host Nvidia GPU, make sure you have the following:
- set the env var `USE_DGPU=true` in the container
- `nvidia-container-toolkit` installed on your host
- set the `deploy` section in compose.
- No X server running on host
```yaml
services:
  fika:
    image: fikadockerimagehere:latest
  fika_dedicated:
    image: fika-dedicated:0.1
    container_name: fika_ded
    volumes:
      - /host/path/to/live/files:/opt/live
      - /host/path/to/fika:/opt/tarkov
    environment:
      - PROFILE_ID=adadadadadadaadadadad
      - SERVER_URL=fika
      - SERVER_PORT=6969
      # Set USE_DGPU to enable installation of nvidia drivers in container and start Xorg server on virtual tty
      - USE_DGPU=true
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

# Environment variabes
## Required

| Env var       | Description                                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `PROFILE_ID`  | ProfileID of the dedicated client you created in step 1                                                                                    |
| `SERVER_URL`  | Server URL, or the name of the service that runs the Fika server if you have it in the same docker-compose stack                           |
| `SERVER_PORT` | Server port, usually `6969`                                                                                                                |

## Optional

| Env var       | Description                                                                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `USE_DGPU`    | Enable passing a GPU resource into the container with `nvidia-container-toolkit`. Make sure you have the required dependencies installed for your host |

## Debug

| Env var             | Description                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `USE_GRAPHICS`      | Disables the `-nographics` parameter when starting the dedicated client. This will significantly increase resource usage.                                                                           |
| `DISABLE_BATCHMODE` | Disable the `-batchmode` parameter when starting the client. This will significantly increase resource usage, but may be a workaround for the strange AI aiming behavior seen on dedicated clients. |
| `XVFB_DEBUG`        | Enables debug output for xvfb (the virtual framebuffer)                                                                                                                                             |

# Troubleshooting
Container immediately exits, crashing with stacktrace in container, permissions errors, wine unable to find EscapeFromTarkov.exe, or wine throwing a page fault on read access to 0000000000000000 exception?

- Double check that you have the `Fika.Dedicated.dll` file in the client's `BepInEx/plugins` folder! The game will crash in the container if you don't have this plugin.
- Check your docker logs output. Maybe you haven't mounted your directories properly? Verify the contents of the Vanilla EFT and FIKA Client directories to make sure all expected files are there. You must mount the vanilla EFT files to `/opt/live`, and a working copy of the FIKA client to `/opt/tarkov`.
- Double check that your file permissions for the FIKA client directory and its contents are correct. The container runs as the user `ubuntu` with uid:gid as 1000:1000, so as long as the files you mount from the host are owned by the **host** user with that uid/gid,
  they can be read by the container.
- If you have SELinux enabled on the host, the container may not be able to read the mounted directories unless you provide the :z option to re-label the mount with the correct SELinux context.
  Be VERY careful with this option! I will not be responsible for anything that happens if you choose to do this.

# TODO
- [ ] Support mounting host X socket to potentially support Windows docker hosts via Vcxsrv or an equivalent Windows X server. With -nographics maybe we don't even need to do this?
