#!/bin/bash
set -e

# The deployment spec 'ocp-libvirt-1-1-1' means respectively:
# Deploy OCP (or OpenShift)
# Use Libvirt as the infrastructure driver
# Deploy 1 k8s controlplane node
# Deploy 1 k8s compute node
# Spread the guests across 1 hypervisor

SPEC='ocp-libvirt-1-1-1'

# The extra nodes overrides the initial deployment spec in the way that
# additional guest machines can be added to the initial deployment.
# In this case this means, deploy a CentOS Stream guest VM called
# nova-compute when the K8s cluster is OKD. These additional extra guests
# will be added to the inventory in the extra-nodes group.
# Depending on what the user requires you can name this
# extra node as novacompute-01 (for deploying the Nova standalone node) or
# ooo-01 (for deploying the standalone TripleO ), or any name you choose.
EXTRA_NODES='[{"name":"novacompute-01","when_distro":["ocp"],"os":"centos"}]'

# This variable makes sure that after the cluster is succesfully deployed
# a role called 'kubeinit_ooonextgen' will be executed.
# In particular this role will be in charge of deploying the podified control
# plane applications in the Kubernetes cluster, and run the tripleo_ansible
# collection to set up the extra guest node that will be used as an OpenStack
# compute node.
EXTRA_ROLES='kubeinit_ooonextgen'

# By default it is assumend that the first hypervisor is called 'nyctea', make
# sure there is SSH passwordless access as root to this HV from the place you
# are running the 'ansible-playbook' command, this can be overriden by using
# -e hypervisor_hosts_spec='[{"ansible_host":"hv_1"},{"ansible_host":"hv_2"}]' \

# Make sure the default DNS is reachable within the network where the cluster is
# deployed, by default it is used 1.1.1.1
export KUBEINIT_COMMON_DNS_PUBLIC='10.38.5.26'

# This line enables to download Openshift. Create this file with your own pull
# secret downloaded from https://console.redhat.com/openshift/install/pull-secret
export KUBEINIT_SECRET_OPENSHIFT_PULLSECRET=~/.kubeinit/.secrets/openshift-pullsecret

# By default both podified and standalone OOO deployments
# are disabled, pass the `kubeinit_ooonextgen_deploy_standalone` or
# the `kubeinit_ooonextgen_deploy_podified` to enable one or other scenario.
EXTRA_VARS='-e kubeinit_ooonextgen_deploy_standalone=true'
# EXTRA_VARS='-e kubeinit_ooonextgen_deploy_podified=true'

# If there is no space on the root partition, this changes the images directory to
# the /home partition
EXTRA_VARS+='-e kubeinit_libvirt_target_image_dir=/home/libvirt/images'

# There is no need to include a static inventory file,
# the hosts groups are built dinamically from the specs.
ansible-playbook \
    --user root \
    -${KUBEINIT_ANSIBLE_VERBOSITY:=v} \q
    -e kubeinit_spec=${SPEC} \
    -e kubeinit_libvirt_cloud_user_create=true \
    -e hypervisor_hosts_spec='[{"ansible_host":"nyctea"}]' \
    -e kubeinit_network_spec='{"network_name":"kimgtnet","network":"10.0.0.0/24"}' \
    -e extra_nodes_spec=${EXTRA_NODES:-[]} \
    -e extra_roles_spec='['${EXTRA_ROLES:-}']' \
    -e compute_node_ram_size=16777216 \
    -e extra_node_ram_size=25165824 \
    -e kubeinit_ignore_validation_checks=true \
    ${EXTRA_VARS:-} \
    ./kubeinit/playbook.yml
