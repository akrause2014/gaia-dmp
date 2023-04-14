# Installation on EIDF Openstack

## Start container

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

## Fix nginx on the zeppelin instance

Remove the `server` section from `/etc/nginx/nginx.conf` so that it picks up the config in `/etc/nginx/conf.d/zeppelin.conf` instead.
```
ssh zeppelin
sudo vi /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

## Create test user (change <password>)
```
source /deployments/zeppelin/bin/create-user-tools.sh
ssh zeppelin "create-shiro-user.sh ak live user <password>"
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

On the zeppelin instance
```
sudo mkdir /data
sudo mount -t nfs4 10.24.3.164:/data /data
hdfs dfs -mkdir -p /data/gaia/GDR3
hdfs dfs -put /data/GDR3/GDR3_GAIASOURCE /data/gaia/GDR3
```

## Pyspark and Spark SQL

Start Pyspark with
```
pyspark
```

Define data location:
```
from gaiadmpconf import conf
conf.GAIA_DATA_LOCATION = 'hdfs:///data/gaia/'
```

Then import Gaia setup:
```
import gaiadmpsetup
```

### Manual attachment of table 'gaia_source'
```
from gaiadmpsetup.gaiadr3_pyspark_schema_structures import gaia_source_schema
from gaiadmpsetup.gaiadmpstore import data_store, reattachParquetFileResourceToSparkContext

reattachParquetFileResourceToSparkContext('gaia_source', data_store + "GDR3/GDR3_GAIASOURCE", [gaia_source_schema])
spark.sql("select * from gaiadr3.gaia_source").show()
```

## Create test user
```
source /deployments/zeppelin/bin/create-user-tools.sh
createshirouser ak live user <password>
ssh zeppelin "create-hdfs-space.sh 'ak' 'live'"
```

## Restart Zeppelin

If required (e.g. data location changes)
```
ssh zeppelin 'zeppelin-daemon.sh restart'
```

## Testing

### Create User

```
source /deployments/zeppelin/bin/create-user-tools.sh

username=$(pwgen 16 1)

createusermain "${username}" \
 | tee "/tmp/${username}.json" \
 | jq '.shirouser | {"username": .name, "password": .password}'

password=$(
  jq -r '.shirouser.password' "/tmp/${username}.json"
)
```

### Data Location

Add the data location to the first notebook.

Create file with the note paragraph to add.
```
cat << 'EOF' | yq -o json '.' | tee "/tmp/datalocation.json"
title: "Set data location"
text: |
  %pyspark
  from gaiadmpconf import conf
  conf.GAIA_DATA_LOCATION = 'hdfs:///data/gaia/'
  import gaiadmpsetup
EOF

> {
>   "title": "Set data location",
>   "text": "%pyspark\nfrom gaiadmpconf import conf\nconf.GAIA_DATA_LOCATION = 'hdfs:///data/gaia/'\nimport gaiadmpsetup\n"
> }

```

Login to Zeppelin with user created above:
```
curl --silent --request 'POST' --cookie-jar "${zepcookies:?}"\
     --data "userName=${username:?}" \
     --data "password=${password:?}" \
     "${zeppelinurl:?}/api/login" \
 | jq '.'
```

Find note id and post to add paragraph to the note. 
```
noteid='2HYED9NTU'
curl --silent --request POST --cookie "${zepcookies:?}" \
     --data "@/tmp/datalocation.json"\
    "${zeppelinurl:?}/api/notebook/${noteid:?}/paragraph" \
 | tee "/tmp/datalocation.out" \
 | jq '.'
```

### Set up SSH tunnel

```
ssh \
    -n \
    -f \
    -N \
    -L 8080:zeppelin:8080 \
    zeppelin

zeppelinurl='http://localhost:8080'
```

### Run tests

```
source /deployments/zeppelin/bin/zeppelin-rest-tools.sh

testall "${username:?}" "${password:?}" \
  | tee "/tmp/${username}-testall.json" \
  | jq '.'
```
