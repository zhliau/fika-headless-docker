# Building
Run the `build` script. The image is tagged `fika-dedicated:0.1`

# Releases
The image build is triggered off commits to master and hosted on ghcr.
```
docker pull ghcr.io/zhliau/fika-headless-docker:master
```

# Running
I've only tested this on my linux host (arch kernel 6.9.8). No guarantees this will work on Windows.

1. Create a profile that the dedicated client will login as. Copy its profileID and set it aside. 
   You can find the profiles in the server `user/profiles` directory. The profileID is the filename of the profile, excluding the `.json` extension
2. Make sure your `Force Bind IP` and `Force IP` values in the fika core config are set correctly. I found it sufficient to set `Force Bind IP` to `Disabled`, and to set `Force IP` to the IP of my host interface
3. You probably want to set your graphics settings to as low as possible on the dedicated client. See `user/sptSettings` in your fika client flder
4. Run the docker image, making sure you have the following configured:
    - Client directory mounted to `/opt/tarkov` in the container. This is the folder containing a copy of the FIKA install.
      Don't forget the `Fika.Dedicated.dll` plugin file, it needs to be in `BepInEx/plugins`.
      If you use modsync on your client, you might want to remove it from here and manually ensure all plugins are the same as your clients' in this BepInEx folder 
    - Live directory mounted to `/opt/live`. This is the directory that contains the `EscapeFromTarkov_BE.exe` executable
    - `PROFILE_ID` env var set to the profile you created in step 1
    - `SERVER_URL` env var set to your server URL
    - `SERVER_PORT` env var set to your server's port
    - (Experimental) `USE_DGPU` env var set to `true`, to enable starting an X server in container in combination with `nvidia-container-toolkit` to use the host GPU resource
      *This will not work if you have an X server running on your host using your GPU already!* This is due to Xorg server limitations.

E.g
```Shell
docker run --name fika_dedicated -v /path/to/client:/opt/tarkov -v /path/to/live:/opt/live -e PROFILE_ID=blah -e SERVER_URL=localhost -e SERVER_PORT=6969 -p 25565:25565/udp fika_dedicated:0.1
```

# docker-compose
Or better yet use a docker-compose file
```yaml
services:
  fika_dedicated:
    image: fika-dedicated:0.1
    container_name: fika_ded
    volumes:
      # If you have SELinux enabled on the host you want the :z option to re-label the mount with the correct SELinux context
      # or else the container can't read these mounted directories. Be VERY careful with this option!
      - /path/to/live/files:/opt/live
      - /path/to/fika:/opt/tarkov
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
      - /path/to/live/files:/opt/live
      - /path/to/fika:/opt/tarkov
    environment:
      - PROFILE_ID=adadadadadadaadadadad
      # Use service DNS name instead of IP
      - SERVER_URL=fika
      - SERVER_PORT=6969
    ports:
      - 25565:25565/udp
```

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
      - /path/to/live/files:/opt/live
      - /path/to/fika:/opt/tarkov
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

# TODO
- [ ] Now that DGPU works via in-container X server, figure out why it makes no difference! Do we need to use VirtualGL still?
- [ ] Overlay mount a custom `sptSettings/Graphics.ini` to set all graphics to Potato just for the container?
