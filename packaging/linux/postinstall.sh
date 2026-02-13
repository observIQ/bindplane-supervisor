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

# Supervisor's installation directory
: "${BINDPLANE_SUPERVISOR_INSTALL_DIR:=/opt/bindplane-supervisor}"

install() {
    mkdir -p "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"
    chmod 0755 "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"
    chown "${BINDPLANE_SUPERVISOR_USER}:${BINDPLANE_SUPERVISOR_GROUP}" "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"

    share_dir="/usr/share/bindplane-supervisor"
    chown -R "${BINDPLANE_SUPERVISOR_USER}:${BINDPLANE_SUPERVISOR_GROUP}" "${share_dir}"
    cp -r --preserve "${share_dir}"/* "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"
    rm -rf "${share_dir}"
}

install_service() {
    if command -v systemctl > /dev/null 2>&1; then
        install_systemd_service
    else
        install_initd_service
    fi
}

install_systemd_service() {
    # Create/update the systemd service file
    config_file="/etc/systemd/system/bindplane-supervisor.service"

    if [ ! -f "$config_file" ]; then
        echo "Installing systemd service to $config_file"
    else
        echo "Updating systemd service file $config_file"
    fi

    mkdir -p "$(dirname "$config_file")"
    cat << EOF > "$config_file"
[Unit]
Description=Bindplane distribution of the OpenTelemetry OpAMP Supervisor
After=network.target
StartLimitIntervalSec=120
StartLimitBurst=5
[Service]
Type=simple
User=${BINDPLANE_SUPERVISOR_USER}
Group=${BINDPLANE_SUPERVISOR_GROUP}
Environment=PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
# Environment variables Bindplane expects for the collector process.
Environment=OIQ_OTEL_COLLECTOR_HOME=${BINDPLANE_SUPERVISOR_INSTALL_DIR}
Environment=OIQ_OTEL_COLLECTOR_STORAGE=${BINDPLANE_SUPERVISOR_INSTALL_DIR}/storage
WorkingDirectory=${BINDPLANE_SUPERVISOR_INSTALL_DIR}
ExecStart=${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor --config supervisor-config.yaml
LimitNOFILE=65000
SuccessExitStatus=0
TimeoutSec=20
StandardOutput=journal
Restart=on-failure
RestartSec=5s
KillMode=control-group
[Install]
WantedBy=multi-user.target
EOF

    # Ensure the override dir exists.
    override_dir="/etc/systemd/system/bindplane-supervisor.service.d"
    if [ ! -d "$override_dir" ]; then
        mkdir -p "$override_dir"
        echo "Created systemd override directory at $override_dir"
    fi
}

install_initd_service() {
    config_file="/etc/init.d/bindplane-supervisor"

    if [ ! -f "$config_file" ]; then
        echo "Installing init.d service to $config_file"
    else
        echo "Updating init.d service file $config_file"
    fi

    mkdir -p "$(dirname "$config_file")"
    cat << EOF > "$config_file"
#!/bin/sh
# Bindplane OpAMP Supervisor daemon
# chkconfig: 2345 99 05
# description: Bindplane distribution of the OpenTelemetry OpAMP Supervisor
# processname: bindplane-supervisor
# pidfile: /var/run/bindplane-supervisor.pid

### BEGIN INIT INFO
# Provides: bindplane-supervisor
# Required-Start:
# Required-Stop:
# Should-Start:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6  
# Description: Start the bindplane-supervisor service
### END INIT INFO

# Source function library.
# RHEL
if [ -e /etc/init.d/functions ]; then
  STATUS=true
  # shellcheck disable=SC1091
  . /etc/init.d/functions
fi
# SUSE
if [ -e /etc/rc.status ]; then
  RCSTATUS=true
  # Shell functions sourced from /etc/rc.status:
  #      rc_check         check and set local and overall rc status
  #      rc_status        check and set local and overall rc status
  #      rc_status -v     ditto but be verbose in local rc status
  #      rc_status -v -r  ditto and clear the local rc status
  #      rc_failed        set local and overall rc status to failed
  #      rc_failed <num>  set local and overall rc status to <num><num>
  #      rc_reset         clear local rc status (overall remains)
  #      rc_exit          exit appropriate to overall rc status
  # shellcheck disable=SC1091
  . /etc/rc.status

  # First reset status of this service
  rc_reset
fi
# LSB Capable
if [ -e /lib/lsb/init-functions ]; then
  PROC=true
  # shellcheck disable=SC1091
  . /lib/lsb/init-functions
fi

# Return values acc. to LSB for all commands but status:
# 0 - success
# 1 - generic or unspecified error
# 2 - invalid or excess argument(s)
# 3 - unimplemented feature (e.g. "reload")
# 4 - insufficient privilege
# 5 - program is not installed
# 6 - program is not configured
# 7 - program is not running
#
# Note that, for LSB, starting an already running service, stopping
# or restarting a not-running service as well as the restart
# with force-reload (in case signalling is not supported) are
# considered a success.

BINARY=supervisor
PROGRAM=${BINDPLANE_SUPERVISOR_INSTALL_DIR}/"\$BINARY"
START_CMD="nohup ${BINDPLANE_SUPERVISOR_INSTALL_DIR}/\$BINARY > /dev/null 2>&1 &"
LOCKFILE=/var/lock/"\$BINARY"
PIDFILE=/var/run/"\$BINARY".pid

# Exported variables Bindplane expects for the collector process.
export OIQ_OTEL_COLLECTOR_HOME=${BINDPLANE_SUPERVISOR_INSTALL_DIR}
export OIQ_OTEL_COLLECTOR_STORAGE=${BINDPLANE_SUPERVISOR_INSTALL_DIR}/storage

RETVAL=0
start() {
  [ -x "\$PROGRAM" ] || exit 5

  # shellcheck disable=SC3037
  echo -n "Starting \$0: "

  # RHEL
  if [ "\$STATUS" ]; then
    umask 077

    daemon --pidfile="\$PIDFILE" "\$START_CMD"
    RETVAL=\$?
    # truncate the pid file, just in case
    : > "\$PIDFILE"
    # shellcheck disable=SC2005
    echo "\$(pidof "\$BINARY")" > "\$PIDFILE"
    [ "\$RETVAL" -eq 0 ] && touch "\$LOCKFILE"
  # SUSE
  elif [ "\$RCSTATUS" ]; then
    ## Start daemon with startproc(8). If this fails
    ## the echo return value is set appropriate.

    # NOTE: startproc return 0, even if service is
    # already running to match LSB spec.
    nohup "\$PROGRAM" --config supervisor.yaml > /dev/null 2>&1 &

    # Remember status and be verbose
    rc_status -v

    # truncate the pid file, just in case
    : > "\$PIDFILE"
    # shellcheck disable=SC2005
    echo "\$(pidof "\$BINARY")" > "\$PIDFILE"
  fi
  echo
}

stop() {
  # shellcheck disable=SC3037
  echo -n "Shutting down \$0: "
  # RHEL
  if [ "\$STATUS" ]; then
      killproc -p "\$PIDFILE" -d30 "\$BINARY"
      RETVAL=\$?
      echo
      [ "\$RETVAL" -eq 0 ] && rm -f "\$LOCKFILE"
      return "\$RETVAL"
  # SUSE
  elif [ "\$RCSTATUS" ]; then
      ## Stop daemon with killproc(8) and if this fails
      ## set echo the echo return value.
      killproc -t30 -p "\$PIDFILE" "\$BINARY"

      # Remember status and be verbose
      rc_status -v
  fi
  echo
}

# Currently unimplemented
reload() {
  echo "Reload is not currently implemented for \$0"
  RETVAL=3
}

# Currently unimplemented
force_reload() {
  echo "Reload is not currently implemented for \$0, redirecting to restart"
  restart
}

pid_not_running() {
  echo " * \$PROGRAM is not running"
  RETVAL=7
}

pid_status() {
  if [ -e "\$PIDFILE" ]; then
    if ps -p "\$(cat "\$PIDFILE")" > /dev/null; then
      echo " * \$PROGRAM" is running, pid="\$(cat "\$PIDFILE")"
    else
      pid_not_running
    fi
  else
    pid_not_running
  fi
}

supervisor_status() {
  if [ -e "\$PIDFILE" ]; then
    # shellcheck disable=SC3037
    echo -n "Status of \$0 (\$(cat "\$PIDFILE")) "
  else
    # shellcheck disable=SC3037
    echo -n "Status of \$0 (no pidfile found) "
  fi

  if [ "\$STATUS" ]; then
    status -p "\$PIDFILE" "\$PROGRAM"
    RETVAL=\$?
  elif [ "\$RCSTATUS" ]; then
    ## Check status with checkproc(8), if process is running
    ## checkproc will return with exit status 0.

    # Status has a slightly different for the status command:
    # 0 - service running
    # 1 - service dead, but /var/run/  pid  file exists
    # 2 - service dead, but /var/lock/ lock file exists
    # 3 - service not running

    # NOTE: checkproc returns LSB compliant status values.
    checkproc -p "\$PIDFILE" "\$PROGRAM"
    rc_status -v
  elif [ "\$PROC" ]; then
    status_of_proc -p "\$PIDFILE" "\$PROGRAM" "\$PROGRAM"
    RETVAL=\$?
  else
    pid_status
  fi
  echo
}

cd "\$BINDPLANE_SUPERVISOR_HOME" || exit 1
case "\$1" in
  # Start the service
  start)
    start
    ;;
  # Stop the service
  stop)
    stop
    ;;
  # Get the status of the service
  status)
    supervisor_status
    ;;
  # Restart the service by stop, then restart
  restart)
    stop
    # sleep for 1 second to prevent false starts leaving us in a bad state
    sleep 1
    start
    ;;
  # Not currently implemented, but should reload the config file
  reload)
    reload
    ;;
  # Not currently implemented, but should reload the config file.
  # If it fails, restart
  force-reload)
    force_reload
    ;;
  # Conditionally restart the service (only if running already)
  condrestart|try-restart)
    otel_status >/dev/null 2>&1 || exit 0
    restart
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart|condrestart|try-restart|reload|force-reload|status}"
    RETVAL=3
    ;;
esac
cd "\$OLDPWD" || exit 1

if [ "\$RCSTATUS" ]; then
  rc_exit
fi

exit "\$RETVAL"
EOF
}

manage_sysv_service() {
  chmod 755 /etc/init.d/bindplane-supervisor
  echo "configured sysv service"
}

manage_systemd_service() {
  systemctl daemon-reload

  echo "configured systemd service"

  cat << EOF

The "bindplane-supervisor" service has been configured!

The supervisor's config file can be found here: 
  ${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor-config.yaml

To view logs from the supervisor, run:
  sudo tail -F ${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor.log

For more information on configuring the supervisor, see the docs:
  https://github.com/observIQ/bindplane-supervisor/tree/main#bindplane-supervisor

To stop the bindplane-supervisor service, run:
  sudo systemctl stop bindplane-supervisor

To start the bindplane-supervisor service, run:
  sudo systemctl start bindplane-supervisor

To restart the bindplane-supervisor service, run:
  sudo systemctl restart bindplane-supervisor

To enable the bindplane-supervisor service on startup, run:
  sudo systemctl enable bindplane-supervisor

If you have any other questions please contact us at support@bindplane.com
EOF
}

init_type() {
  # Determine if we need service or systemctl for prereqs
  if command -v systemctl > /dev/null 2>&1; then
    command printf "systemd"
    return
  elif command -v service > /dev/null 2>&1; then
    command printf "service"
    return
  fi

  command printf "unknown"
  return
}

manage_service() {
  service_type="$(init_type)"
  case "$service_type" in
    systemd)
      manage_systemd_service
      ;;
    service)
      manage_sysv_service
      ;;
    *)
      echo "Could not detect init system, skipping service configuration"
      ;;
  esac
}

install
install_service
manage_service
