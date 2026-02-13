#!/bin/sh

set -e

# Read's optional package overrides. Users should deploy the override
# file before installing for the first time. The override should
# not be modified unless uninstalling and re-installing.
[ -f /etc/default/bindplane-supervisor ] && . /etc/default/bindplane-supervisor
[ -f /etc/sysconfig/bindplane-supervisor ] && . /etc/sysconfig/bindplane-supervisor

# Configurable runtime user/group
: "${BINDPLANE_SUPERVISOR_USER:=bindplane-supervisor}"
: "${BINDPLANE_SUPERVISOR_GROUP:=bindplane-supervisor}"

# Install creates the user and group for the collector
# service. This function is idempotent and safe to call
# multiple times.
install() {
    install_group_user
}

# install_group_user creates the group and user for the supervisor service.
install_group_user() {
    # Check if the group and user already exist and return if they do
    if getent group "${BINDPLANE_SUPERVISOR_GROUP}" > /dev/null && id "${BINDPLANE_SUPERVISOR_USER}" >/dev/null 2>&1; then
        return
    fi

    # Create the group
    if ! getent group "${BINDPLANE_SUPERVISOR_GROUP}" > /dev/null; then
        echo "Creating group ${BINDPLANE_SUPERVISOR_GROUP}"
        groupadd -r "${BINDPLANE_SUPERVISOR_GROUP}"
    else
        echo "Group ${BINDPLANE_SUPERVISOR_GROUP} already exists"
    fi

    # Create the user
    if ! id "${BINDPLANE_SUPERVISOR_USER}" >/dev/null 2>&1; then
        echo "Creating user ${BINDPLANE_SUPERVISOR_USER}"
        useradd --shell /sbin/nologin --system "${BINDPLANE_SUPERVISOR_USER}" -g "${BINDPLANE_SUPERVISOR_GROUP}"
    else
        echo "User ${BINDPLANE_SUPERVISOR_USER} already exists"
    fi
}

install
