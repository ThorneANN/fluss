#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


USAGE="Usage: fluss-daemon.sh (start|stop|stop-all) (coordinator-server|tablet-server|zookeeper) [args]"


STARTSTOP=$1
DAEMON=$2
ARGS=("${@:3}") # get remaining arguments as array

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/config.sh

case $DAEMON in
    (coordinator-server)
        CLASS_TO_RUN=com.alibaba.fluss.server.coordinator.CoordinatorServer
    ;;

    (tablet-server)
        CLASS_TO_RUN=com.alibaba.fluss.server.tablet.TabletServer
    ;;

    (zookeeper)
        CLASS_TO_RUN=com.alibaba.fluss.shaded.zookeeper3.org.apache.zookeeper.server.quorum.QuorumPeerMain
    ;;

    (*)
        echo "Unknown daemon '${DAEMON}'. $USAGE."
        exit 1
    ;;
esac

if [ "$FLUSS_IDENT_STRING" = "" ]; then
    FLUSS_IDENT_STRING="$USER"
fi

FLUSS_CLASSPATH=`constructFlussClassPath`

pid=$FLUSS_PID_DIR/fluss-$FLUSS_IDENT_STRING-$DAEMON.pid

mkdir -p "$FLUSS_PID_DIR"


# Log files are indexed from the process ID's position in the PID
# file. The following lock prevents a race condition during daemon startup
# when multiple daemons read, index, and write to the PID file concurrently.
# The lock is created on the PID directory since a lock file cannot be safely
# removed. The daemon is started with the lock closed and the lock remains
# active in this script until the script exits.
command -v flock >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    exec 200<"$FLUSS_PID_DIR"
    flock 200
fi

# Ascending ID depending on number of lines in pid file.
# This allows us to start multiple daemon of each type.
id=$([ -f "$pid" ] && echo $(wc -l < "$pid") || echo "0")

FLUSS_LOG_PREFIX="${FLUSS_LOG_DIR}/fluss-${FLUSS_IDENT_STRING}-${DAEMON}-${id}-${HOSTNAME}"
log="${FLUSS_LOG_PREFIX}.log"
out="${FLUSS_LOG_PREFIX}.out"

log_setting=("-Dlog.file=${log}" "-Dlog4j.configuration=file:${FLUSS_CONF_DIR}/log4j.properties" "-Dlog4j.configurationFile=file:${FLUSS_CONF_DIR}/log4j.properties" "-Dlogback.configurationFile=file:${FLUSS_CONF_DIR}/logback.xml")

function guaranteed_kill {
  to_stop_pid=$1
  daemon=$2

  # send sigterm for graceful shutdown
  kill $to_stop_pid
  # if timeout exists, use it
  if command -v timeout &> /dev/null ; then
    # wait 10 seconds for process to stop. By default, Fluss kills the JVM 5 seconds after sigterm.
    timeout 10 tail --pid=$to_stop_pid -f /dev/null &> /dev/null
    if [ "$?" -eq 124 ]; then
      echo "Daemon $daemon didn't stop within 10 seconds. Killing it."
      # send sigkill
      kill -9 $to_stop_pid
    fi
  fi
}

case $STARTSTOP in

    (start)

        # Print a warning if daemons are already running on host
        if [ -f "$pid" ]; then
          active=()
          while IFS='' read -r p || [[ -n "$p" ]]; do
            kill -0 $p >/dev/null 2>&1
            if [ $? -eq 0 ]; then
              active+=($p)
            fi
          done < "${pid}"

          count="${#active[@]}"

          if [ ${count} -gt 0 ]; then
            echo "[INFO] $count instance(s) of $DAEMON are already running on $HOSTNAME."
          fi
        fi

        # Evaluate user options for local variable expansion
        FLUSS_ENV_JAVA_OPTS=$(eval echo ${FLUSS_ENV_JAVA_OPTS})

        echo "Starting $DAEMON daemon on host $HOSTNAME."

        # when jdk version is 17 or above, need to add following option to make arrow works
        # see https://arrow.apache.org/docs/dev/java/install.html#java-compatibility
        if is_jdk_version_ge_17 "$JAVA_RUN" ; then
            JVM_ARGS="${JVM_ARGS} --add-opens=java.base/java.nio=org.apache.arrow.memory.core,ALL-UNNAMED"
        fi

        "$JAVA_RUN" $JVM_ARGS ${FLUSS_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "`manglePathList "$FLUSS_CLASSPATH"`" ${CLASS_TO_RUN} "${ARGS[@]}" > "$out" 200<&- 2>&1 < /dev/null &

        mypid=$!

        # Add to pid file if successful start
        if [[ ${mypid} =~ ${IS_NUMBER} ]] && kill -0 $mypid > /dev/null 2>&1 ; then
            echo $mypid >> "$pid"
        else
            echo "Error starting $DAEMON daemon."
            exit 1
        fi
    ;;

    (stop)
        if [ -f "$pid" ]; then
            # Remove last in pid file
            to_stop=$(tail -n 1 "$pid")

            if [ -z $to_stop ]; then
                rm "$pid" # If all stopped, clean up pid file
                echo "No $DAEMON daemon to stop on host $HOSTNAME."
            else
                sed \$d "$pid" > "$pid.tmp" # all but last line

                # If all stopped, clean up pid file
                [ $(wc -l < "$pid.tmp") -eq 0 ] && rm "$pid" "$pid.tmp" || mv "$pid.tmp" "$pid"

                if kill -0 $to_stop > /dev/null 2>&1; then
                    echo "Stopping $DAEMON daemon (pid: $to_stop) on host $HOSTNAME."
                    guaranteed_kill $to_stop $DAEMON
                else
                    echo "No $DAEMON daemon (pid: $to_stop) is running anymore on $HOSTNAME."
                fi
            fi
        else
            echo "No $DAEMON daemon to stop on host $HOSTNAME."
        fi
    ;;

    (stop-all)
        if [ -f "$pid" ]; then
            mv "$pid" "${pid}.tmp"

            while read to_stop; do
                if kill -0 $to_stop > /dev/null 2>&1; then
                    echo "Stopping $DAEMON daemon (pid: $to_stop) on host $HOSTNAME."
                    guaranteed_kill $to_stop $DAEMON
                else
                    echo "Skipping $DAEMON daemon (pid: $to_stop), because it is not running anymore on $HOSTNAME."
                fi
            done < "${pid}.tmp"
            rm "${pid}.tmp"
        fi
    ;;

    (*)
        echo "Unexpected argument '$STARTSTOP'. $USAGE."
        exit 1
    ;;

esac