# Gitlab in azure

**Work in progress**

Set up gitlab + gitlab-runner in two vm's in Azure.

## Install infrastruture

Creates 2 machines, one for gitlab, another for the runner

Requires terraform (v0.10.7).

    export RESOURCE_GROUP=<thenewrg>
    terraform plan  -var resource_group=$RESOURCE_GROUP
    terraform apply -var resource_group=$RESOURCE_GROUP

## Configuration

Requires ansible (2.4.0.0).

Create inventory.yml and setup the correct hosts. Check group_vars/all (eg. resource_group must be the same as specified for terraform).

#### Gitlab

    ansible -i azure-rm.py gitlab-setup.yml

Go to gitlab1, change username, email and add ssh key. 


#### Gitlab runner

    ansible -i azure-rm.py gitlabci-setup.yml

Ssh to gitlabci machine and finish setup - see https://docs.gitlab.com/runner/install/linux-repository.htm. 

Register up runners (https://docs.gitlab.com/ce/ci/runners/)


