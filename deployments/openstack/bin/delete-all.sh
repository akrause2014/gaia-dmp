#!/bin/sh
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2020, ROE (http://www.roe.ac.uk/)
#
#     This information is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This information is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
#   </meta:licence>
# </meta:header>
#
#

# -----------------------------------------------------
# Settings ...

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname:?}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Set the Manila API version.
# https://stackoverflow.com/a/58806536

    source /deployments/openstack/bin/settings.sh


# ----------------------------------------------------------------
# Check if we are deleting live, confirm before continuing if yes


    live_hostname=$(ssh  -o "StrictHostKeyChecking no" fedora@live.gaia-dmp.uk 'hostname')

    if [[ "$live_hostname" == *"$cloudname"* ]]; then
        read -p "You are deleting the current live system!! Do you want to proceed? (y/N) " -n 1 -r
        echo
        if [[ $REPLY != "y" ]];
        then
            exit
        fi
    fi


# -----------------------------------------------------
# Sanity check.

    if [ "${cloudname}" == "iris-gaia-data" ]
    then
        echo
        echo "DANGER: Do not run delete-all on [${cloudname}]"
        echo
        exit 1
    fi


# -----------------------------------------------------
# Delete any Mangum clusters.
# First attempt to shutdown the autoscaling response.

    echo ""
    echo "---- ----"
    echo "Deleting clusters"

    # TODO Move to common tools
    pullstatus()
        {
        local clid=${1:?}
        openstack \
            --os-cloud "${cloudname:?}"-super \
            coe cluster show \
                --format json \
                "${clid:?}" \
        > '/tmp/cluster-status.json'
        # TODO Catch HTTP 404 error
        # TODO re-direct stderr
        }

    jsonstatus()
        {
        jq -r '.status' '/tmp/cluster-status.json'
        # TODO Catch blank file
        }

    bothstatus()
        {
        local clid=${1:?}
        pullstatus "${clid:?}"
        jsonstatus
        }

    for clusterid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            coe cluster list \
                --format json \
        | jq -r '.[] | .uuid'
        )
    do
        echo "- Deleting cluster [${clusterid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            coe cluster \
                delete \
                "${clusterid:?}"

        # TODO Handle empty response
         while [ $(bothstatus ${clusterid:?}) == 'DELETE_IN_PROGRESS' ]
            do
                echo "IN PROGRESS"
                sleep 10
            done

        if [ $(jsonstatus) == 'DELETE_FAILED' ]
        then
            echo "DELETE FAILED"
            jq '
                {status, faults}
                ' '/tmp/cluster-status.json'
        fi
    done


# -----------------------------------------------------
# Delete any servers.

    echo ""
    echo "---- ----"
    echo "Deleting servers"

    for serverid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            server list \
                --format json \
        | jq -r '.[] | .ID'
        )
    do
        echo "- Deleting server [${serverid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            server delete \
                "${serverid:?}"
    done


# -----------------------------------------------------
# Delete any volumes.

    echo ""
    echo "---- ----"
    echo "Deleting volumes"

    for volumeid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            volume list \
                --format json \
        | jq -r '.[] | .ID'
        )
    do
        echo "- Deleting volume [${volumeid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            volume delete \
                "${volumeid:?}"
    done


# -----------------------------------------------------
# Delete any shares.

    echo ""
    echo "---- ----"
    echo "Deleting shares"

    if [ "${cloudname}" == "iris-gaia-data" ]
    then
        echo
        echo "Skipping delete shares for [${cloudname}]"
        echo
    else
        for sharename in $(
            openstack \
                --os-cloud "${cloudname:?}" \
                share list \
                    --format json \
            | jq -r ".[] | select(.Name | startswith(\"${cloudname}\")) | .Name"
            )
        do
            echo "- Deleting share [${sharename}]"
            openstack \
                --os-cloud "${cloudname:?}" \
                share delete \
                    "${sharename}"
        done
    fi


# -----------------------------------------------------
# Release any floating IP addresses.

    echo ""
    echo "---- ----"
    echo "Releasing addresses"

    for floatingid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            floating ip list \
                --format json \
        | jq -r '.[] | .ID'
        )
        do
            echo "- Releasing address [${floatingid}]"
            openstack \
                --os-cloud "${cloudname:?}" \
                floating ip unset \
                    "${floatingid}"

            openstack \
                --os-cloud "${cloudname:?}" \
                floating ip delete \
                    "${floatingid}"
        done


# -----------------------------------------------------
# Delete any routers.

    echo ""
    echo "---- ----"
    echo "Deleting routers"

    for routerid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            router list \
                --format json \
        | jq -r '.[] | .ID'
        )
    do

        echo "- Router [${routerid}]"

        echo "-- Deleting routes"
        for routedesc in $(
            openstack \
                --os-cloud "${cloudname:?}" \
                router show \
                    --format json \
                    "${routerid:?}" \
            | jq -r '.routes[] | "gateway=" + .nexthop + ",destination=" + .destination'
            )
        do
            echo "--- Deleting route [${routedesc}]"
            openstack \
                --os-cloud "${cloudname:?}" \
                router unset \
                    --route "${routedesc:?}" \
                    "${routerid:?}"
        done

        echo "-- Deleting ports"
        for portid in $(
            openstack \
                --os-cloud "${cloudname:?}" \
                router show \
                    --format json \
                    "${routerid:?}" \
                | jq -r '.interfaces_info[].port_id'
                )
                do
                    echo "--- Deleting port [${portid}]"
                    openstack \
                        --os-cloud "${cloudname:?}" \
                        router remove port \
                            "${routerid:?}" \
                            "${portid:?}"
                done

        echo "- Deleting router [${routerid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            router delete \
                "${routerid:?}"
    done


# -----------------------------------------------------
# Delete any extra subnets.

    echo ""
    echo "---- ----"
    echo "Deleting subnets"

    for subnetid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            subnet list \
                --format json \
        | jq -r '.[] | select(
            (.Name != "CUDN-Internet")
            and
            (.Name != "cephfs")
            ) | .ID'
        )
    do
        echo "- Subnet [${subnetid}]"

        echo "-- Deleting subnet ports"
        for subportid in $(
                openstack \
                    --os-cloud "${cloudname:?}" \
                    port list \
                        --fixed-ip "subnet=${subnetid:?}" \
                        --format json \
                | jq -r '.[] | .ID'
                )

        do
            echo "--- Deleting subnet port [${subportid}]"
            openstack \
                --os-cloud "${cloudname:?}" \
                port delete \
                    "${subportid:?}"

        done

        echo "- Deleting subnet [${subnetid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            subnet delete \
                "${subnetid:?}"
    done


# -----------------------------------------------------
# Delete any extra networks.
# TODO Configurable list of networks to ignore ?
# https://stackoverflow.com/questions/44563115/how-to-use-jq-to-filter-select-items-not-in-list

    echo ""
    echo "---- ----"
    echo "Deleting networks"

    for networkid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            network list \
                --format json \
        | jq -r '.[] | select(
            (.Name != "CUDN-Internet")
            and
            (.Name != "cephfs")
            ) | .ID'
        )
    do
        echo "- Deleting network [${networkid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            network delete \
                "${networkid:?}"
    done


# -----------------------------------------------------
# Delete any extra security groups.

    echo ""
    echo "---- ----"
    echo "Deleting security groups"

    for groupid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            security group list \
                --format json \
        | jq -r '.[] | select(.Name != "default") | .ID'
        )
    do
        echo "- Deleting security group [${groupid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            security group delete \
                "${groupid:?}"
    done


# -----------------------------------------------------
# Delete any keypairs that match this cloud.

    echo ""
    echo "---- ----"
    echo "Deleting ssh keys"

    for keyname in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            keypair list \
                --format json \
        | jq -r ".[] | select(.Name | startswith(\"${cloudname}\")) | .Name"
        )
    do
        echo "- Deleting key [${keyname:?}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            keypair delete \
                "${keyname:?}"
    done


# -----------------------------------------------------
# Delete any remaining Mangum clusters.
# Second attempt after deleting the extra routers and subnets.

    echo ""
    echo "---- ----"
    echo "Deleting clusters"

    # TODO Move to common tools
    pullstatus()
        {
        local clid=${1:?}
        openstack \
            --os-cloud "${cloudname:?}"-super \
            coe cluster show \
                --format json \
                "${clid:?}" \
        > '/tmp/cluster-status.json'
        # TODO Catch HTTP 404 error
        # TODO re-direct stderr
        }

    jsonstatus()
        {
        jq -r '.status' '/tmp/cluster-status.json'
        # TODO Catch blank file
        }

    bothstatus()
        {
        local clid=${1:?}
        pullstatus "${clid:?}"
        jsonstatus
        }

    for clusterid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            coe cluster list \
                --format json \
        | jq -r '.[] | .uuid'
        )
    do
        echo "- Deleting cluster [${clusterid}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            coe cluster \
                delete \
                "${clusterid:?}"

        # TODO Handle empty response
         while [ $(bothstatus ${clusterid:?}) == 'DELETE_IN_PROGRESS' ]
            do
                echo "IN PROGRESS"
                sleep 10
            done

        if [ $(jsonstatus) == 'DELETE_FAILED' ]
        then
            echo "DELETE FAILED"
            cat '/tmp/cluster-status.json'
        fi
    done



# -----------------------------------------------------
# List the remaining resources.

    echo ""
    echo "---- ----"
    echo "List servers"
    openstack \
        --os-cloud "${cloudname:?}" \
        server list

    echo ""
    echo "---- ----"
    echo "List volumes"
    openstack \
        --os-cloud "${cloudname:?}" \
        volume list

    echo ""
    echo "---- ----"
    echo "List shares"
    openstack \
        --os-cloud "${cloudname:?}" \
        share list

    echo ""
    echo "---- ----"
    echo "List addresses"
    openstack \
        --os-cloud "${cloudname:?}" \
        floating ip list

    echo ""
    echo "---- ----"
    echo "List routers"
    openstack \
        --os-cloud "${cloudname:?}" \
        router list

    echo ""
    echo "---- ----"
    echo "List networks"
    openstack \
        --os-cloud "${cloudname:?}" \
        network list

    echo ""
    echo "---- ----"
    echo "List subnets"
    openstack \
        --os-cloud "${cloudname:?}" \
        subnet list

    echo ""
    echo "---- ----"
    echo "List security groups"
    openstack \
        --os-cloud "${cloudname:?}" \
        security group list

    echo ""
    echo "---- ----"
    echo "List ssh keys"
    openstack \
        --os-cloud "${cloudname:?}" \
        keypair list

    echo ""
    echo "---- ----"
    echo "List clusters"
    openstack \
        --os-cloud "${cloudname:?}" \
        coe cluster list

    echo "---- ----"
    echo "Done"




