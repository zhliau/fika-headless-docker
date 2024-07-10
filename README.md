# Building
Run the `build` script. The image is tagged `fika-dedicated:0.1`

# Running
1. Create a profile that the dedicated client will login as. Copy its profileID and set it aside. 
   You can find the profiles in the server `user/profiles` directory. The profileID is the filename of the profile, excluding the `.json` extension
2. Make sure your `Force Bind IP` and `Force IP` values in the fika core config are set correctly. I found it sufficient to set `Force Bind IP` to `Disabled`, and to set `Force IP` to the IP of my host interface
3. Run the dockerfile, making sure you have the following configured:
    - Client directory mounted to `/opt/tarkov` in the container. This is the folder containing a copy of the FIKA install.
      Don't forget the `Fika.Dedicated.dll` plugin file, it needs to be in `BepInEx/plugins`.
      If you use modsync on your client, you might want to remove it from here and manually ensure all plugins are the same as your clients' in this BepInEx folder 
    - Live directory mounted to `/opt/live`. This is the directory that contains the `EscapeFromTarkov_BE.exe` executable
    - `PROFILE_ID` env var set to the profile you created in step 1
    - `SERVER_URL` env var set to your server URL
    - `SERVER_PORT` env var set to your server's port

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

*(Not fully working yet)* If you want to pass in your host GPU, make sure you have `nvidia-container-toolkit` installed on your host and specify the `deploy` section.
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
- [ ] Figure out how to ditch Xvfb and use something like VirtualGL so that wine can use hardware acceleration.
  Right now it falls back to LLVMPipe even if we pass in the nvidia GPU and `nvidia-smi` reports the GPU correcty in the container, all because Xvfb is software-rendering only
