#!/bin/bash
PIDFILE="/tmp/s2t_recording.pid"
LOGFILE="/tmp/s2t_debug.log"

echo "$(date): Toggle pressed, PIDFILE exists: $([ -f "$PIDFILE" ] && echo 'YES' || echo 'NO')" >> "$LOGFILE"

if [ -f "$PIDFILE" ]; then
    echo "$(date): Stopping recording" >> "$LOGFILE"
    "/media/filip/roboczy/gitlab_roboczy/Linux Speech-to-Text/stop_and_process_recording_cpu.sh"
    rm "$PIDFILE"
else
    echo "$(date): Starting recording" >> "$LOGFILE"
    "/media/filip/roboczy/gitlab_roboczy/Linux Speech-to-Text/start_recording.sh" &
    echo $! > "$PIDFILE"
fi