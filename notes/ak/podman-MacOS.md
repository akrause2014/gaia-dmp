# Using podman on MacOS

## SSH agent

```
eval `ssh-agent -s`
ssh-add
```

## Start podman machine

Init (if required) and start
```
podman machine init
podman machine start
```

A number of folders are mounted automatically to the machine:
```
Mounting volume... /Users:/Users
Mounting volume... /private:/private
Mounting volume... /var/folders:/var/folders
```
The last one `/var/folders` contains the ssh agent socket.

## Log in to podman machine

```
podman machine ssh
```

## Populate environment variables

Personal
```
WFAU_HOME=/Users/amy/WFAU
CLOUD_CONFIG=${WFAU_HOME:?}/clouds.yaml
AGLAIS_CODE=${WFAU_HOME:?}/gaia-dmp
```

Generic
```
agcolour=red
configname=zeppelin-54.86-spark-6.26.43
agproxymap=3000:3000
clientname=ansibler-${agcolour}
cloudname=iris-gaia-${agcolour}
```

```
podman run \
    --rm \
    --tty \
    --interactive \
    --privileged \
    --name     "${clientname:?}" \
    --hostname "${clientname:?}" \
    --publish  "${agproxymap:?}" \
    --env "cloudname=${cloudname:?}" \
    --env "configname=${configname:?}" \
    --env "SSH_AUTH_SOCK=/mnt/ssh_auth_sock" \
    --volume "${SSH_AUTH_SOCK:?}:/mnt/ssh_auth_sock:rw,z" \
    --volume "${CLOUD_CONFIG:?}:/etc/openstack/clouds.yaml" \
    --volume "${AGLAIS_CODE:?}/deployments:/deployments" \
    ghcr.io/wfau/atolmis/ansible-client:2022.07.25 \
    bash
```
