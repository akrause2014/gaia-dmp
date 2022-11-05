# Installation on EIDF Openstack

## Start container

```
export AGLAIS_CODE=/home/ubuntu/gaia-dmp/
eval `ssh-agent -s`
```

```
podman run --rm --tty --interactive \
    --volume "${HOME:?}/clouds.yaml:/etc/openstack/clouds.yaml:ro,z" \
    --volume "${AGLAIS_CODE:?}/deployments:/deployments:ro,z" \
    ghcr.io/wfau/atolmis/ansible-client:2022.07.25 bash
```

```
podman run --rm --tty --interactive \
    --volume "${HOME:?}/clouds.yaml:/etc/openstack/clouds.yaml:ro,z" \
    --volume "${AGLAIS_CODE:?}/deployments:/deployments:ro,z" \
    --env "SSH_AUTH_SOCK=/mnt/ssh_auth_sock" \
    --volume "${SSH_AUTH_SOCK:?}:/mnt/ssh_auth_sock:rw,z" \
    --env "cloudname=iris-gaia" --env "configname=zeppelin-eidf" \
    ghcr.io/wfau/atolmis/ansible-client:2022.07.25 bash

## Delete all in Openstack project

Run
```
/deployments/openstack/bin/delete-all.sh $cloudname
```
This deletes all servers, networks, routers, security groups, ...

## Create

```
/deployments/hadoop-yarn/bin/create-all.sh $cloudname $configname
```

## Create test user
```
source /deployments/zeppelin/bin/create-user-tools.sh
createshirouser ak live user <password>
ssh zeppelin "create-hdfs-space.sh 'ak' 'live'"
```
