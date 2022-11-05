# Installation on EIDF Openstack

## Start container

<<<<<<< HEAD
Set up environment:
```
export AGLAIS_CODE=/home/akrause/gaia-dmp/
eval `ssh-agent -s`
ssh-add
```

Start client container:
```
podman run --rm --tty --interactive \
    --volume "${HOME:?}/clouds.yaml:/etc/openstack/clouds.yaml:ro,z" \
    --volume "${AGLAIS_CODE:?}/deployments:/deployments:ro,z" \
    --env "SSH_AUTH_SOCK=/mnt/ssh_auth_sock" \
    --volume "${SSH_AUTH_SOCK:?}:/mnt/ssh_auth_sock:rw,z" \
    --env "cloudname=iris-gaia" --env "configname=zeppelin-eidf" \
    ghcr.io/wfau/atolmis/ansible-client:2022.07.25 bash
```

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

<<<<<<< HEAD
## Fix nginx on the zeppelin instance

Remove the `server` section from `/etc/nginx/nginx.conf` so that it picks up the config in `/etc/nginx/conf.d/zeppelin.conf` instead.
```
ssh zeppelin
sudo vi /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

## Create test user
```
source /deployments/zeppelin/bin/create-user-tools.sh
ssh zeppelin "createshirouser ak live user <password>"
ssh zeppelin "create-hdfs-space.sh 'ak' 'live'"
```

# Zeppelin example

```
%spark.pyspark

sc.version
```

## Openstack client
```
openstack --os-cloud $cloudname server list
```

## Copy Gaia data

```
sudo mkdir /data
sudo mount -t nfs4 10.24.3.164:/data /data
hdfs dfs -mkdir /data/gaia/GDR3
hdfs dfs -put /data/GDR3 /data/gaia/
```

## Pyspark and Spark SQL

Start Pyspark with
```
GAIA_DMP_STORE=hdfs:////data/gaia/ pyspark
```

```
from gaiadmpsetup.gaiadr3_pyspark_schema_structures import gaia_source_schema
from gaiadmpsetup.gaiadmpstore import data_store, reattachParquetFileResourceToSparkContext

reattachParquetFileResourceToSparkContext('gaia_source', data_store + "GDR3/GDR3_GAIASOURCE", [gaia_source_schema])
spark.sql("select * from gaiadr3.gaia_source").show()
```
=======
## Create test user
```
source /deployments/zeppelin/bin/create-user-tools.sh
createshirouser ak live user <password>
ssh zeppelin "create-hdfs-space.sh 'ak' 'live'"
```
