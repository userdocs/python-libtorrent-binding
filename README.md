# Introduction

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/1525607f572c4b0384cd66cc366e041b)](https://app.codacy.com/gh/userdocs/python-libtorrent-binding?utm_source=github.com&utm_medium=referral&utm_content=userdocs/python-libtorrent-binding&utm_campaign=Badge_Grade)
[![CodeFactor](https://www.codefactor.io/repository/github/userdocs/python-libtorrent-binding/badge)](https://www.codefactor.io/repository/github/userdocs/python-libtorrent-binding)

This is a build script to create, and optionally install, `libtorrent.so` statically linked against `openssl`, libtorrent `1.1`, `1.2` or `2.0` and `boost-python`. `wolfssl` is available as an alternative to `openssl` when using libtorrent v2 onwards.

This makes setting up `Deluge` + `libtorrent` + `ltconfig 2` an automated and reasonably quick installation by copy and pasting a few commands.

Based on these docs:

<http://www.libtorrent.org/building.html>

<http://www.libtorrent.org/python_binding.html>

## Build script usage

-   The script will install the required dependencies when run as a root or using a docker image.
-   You can setup the build environment as root and then use the build function as a local user.
-   The script is designed to work with a docker image/container and works with [docker rootless](https://docs.docker.com/engine/security/rootless/)

There are three stages to the script depending on what requirements it detects.

-   It will update the system and require a reboot to proceed, if required.
-   If no reboot is required it will continue to install the build environment dependencies and exit unless a module was passed as an argument.
-   If the run using a module argument like `all` it will start building `libtorrent-python-binding` or the specified module using `python3`.

## Help options

The script tries to be automated and helpful but here are the help options to guide you.

```none
Here are a list of available options

 Use: -b  or --build-directory   Help: -h-b  or --help-build-directory
 Use: -c  or --crypto            Help: -h-c  or --help-crypto
 Use: -n  or --no-delete         Help: -h-n  or --help-no-delete
 Use: -lm or --libtorrent-master Help: -h-lm or --help-libtorrent-master
 Use: -lt or --libtorrent-tag    Help: -h-lt or --help-libtorrent-tag
 Use: -p  or --proxy             Help: -h-p  or --help-proxy
 Use: -pv or --python-version    Help: -h-pv or --help-python-version
 Use: -tb or --test-build        Help: -h-tb or --help-test-build
 Use: -s  or --scope             Help: -h-s  or --help-scope

Module specific help - flags are used with the modules listed here.

Use: all or module-name         Usage: ~/musl-libtorrent-python.sh all

 all         - Install all modules - openssl boost libtorrent
 openssl     - Install the openssl module (default)
 wolfssl     - Install the wolf module (Libtorrent v2 only)
 boost       - Download, extract and bootstrap the boost build files
 libtorrent  - Build the libtorrent python binding
```

## Installation

There are two ways to use the script

-   With a docker image for the relevant platform.
-   Run directly on the system where you want to build the binding.

### Debian or Ubuntu

Using Docker

-   Port `8112` for deluge installation.
-   Built to `$HOME/bindings`

#### All in one Ubuntu/Debian docker command

**Note:** This command can be configured using flags top provide a specific outcome. Change `ubuntu:20.04` to `debian:stable` to use Debian.

```bash
docker run -it -p 8112:8112 -v $HOME/bindings:/root ubuntu:20.04 /bin/bash -c 'cd && apt-get update && apt-get install -y curl && curl -sL git.io/gplibtorrent | bash -s all && bash'
```

#### Optional - Setup Ubuntu/Debian Docker fist

Optionally you could create and configure the docker first and then use the script from within the container.

```bash
docker run -it -p 8112:8112 -v $HOME/bindings:/root ubuntu:20.04 /bin/bash -c 'cd && apt-get update && apt-get install -y curl && bash'
```

#### Optional - Download and run inside Ubuntu/Debian docker

Now you can call commands from within the docker container.

```bash
curl -sL git.io/gplibtorrent | bash -s all
```

**Note:** You can modify this part `bash -s all` in either method to customise the behaviour of the command. Refer to the help section above.

#### Using glibc script

**Note:** You can do this from within a docker container as well.

```bash
wget -qO ~/libtorrent-python-binding.sh https://git.io/gplibtorrent
chmod 700 ~/libtorrent-python-binding.sh
~/libtorrent-python-binding.sh
```

### Alpine

Using Docker

-   Port `8112` for deluge installation.
-   Built to `$HOME/bindings`

#### All in one Alpine docker command

**Note:** This command can be configured using flags top provide a specific outcome.

```bash
docker run -it -p 8112:8112 -v $HOME/bindings:/root alpine:3.12 /bin/ash -c 'cd && apk update && apk add bash curl && curl -sL git.io/mplibtorrent | bash -s all && ash'
```

#### Optional - Setup Alpine Docker fist

Optionally you could create and configure the docker first and then use the script from within the container.

```bash
docker run -it -p 8112:8112 -v $HOME/bindings:/root alpine:3.12 /bin/ash -c 'cd && apk update && apk add bash curl && ash'
```

#### Optional - Download and run inside Alpine docker

Now you can call commands from within the docker container.

```bash
curl -sL git.io/mplibtorrent | bash -s all
```

**Note:** You can modify this part `bash -s all` in either method to customise the behaviour of the command. Refer to the help section above.

#### Using musl script

**Note:** You can do this from within a docker container as well.

```bash
wget -qO ~/libtorrent-python-binding.sh https://git.io/mplibtorrent
chmod 700 ~/libtorrent-python-binding.sh
~/libtorrent-python-binding.sh
```

### Some configuration examples

`all` - Install defaults `openssl` > `boost` > `libtorrent` using `v1.2.*` latest version

`all pv 2 -lt libtorrent-1_1_14` - Install `openssl` > `boost` > `libtorrent` using the release `1.1.14` built with `python2`

`all -lm` - Install defaults `openssl` > `boost` > `libtorrent` `RC_1_2` main branch

`all -lt RC_2_0` - Install defaults `openssl` > `boost` > `libtorrent` using the `RC_2_0` main branch

`all pv 2 -lt RC_2_0` - Install defaults `openssl` > `boost` > `libtorrent` using the `RC_2_0` main branch built `python2`

`all -c wolfssl -lt v2.0.1` - Install `wolfssl` > `boost` > `libtorrent` using the release `v2.0.1` built with `python3`

`all pv 2 -c wolfssl -lt v2.0.1` - Install `wolfssl` > `boost` > `libtorrent` using the release `v2.0.1` built with `python2`

## Post build

Once the script is finished the required files will be built

`~/libtorrent-python/completed`

You can install deluge by using the command:

```bash
~/libtorrent-python-binding.sh install
```

It will install to the `~/.local` directory of the user running the script.

**Note:** This script does not attempt to configure deluge.
