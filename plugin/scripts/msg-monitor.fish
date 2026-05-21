#!/usr/bin/env fish
# msg-monitor — watches agent inboxes for new messages.
# Writes notifications to a log file (works around fish stdout buffering).
#
# Usage:
#   msg-monitor hermes              # watch hermes inboxes (10s poll)
#   msg-monitor hermes 5            # custom poll interval
#   msg-monitor claude1
#   msg-monitor claude2
#   msg-monitor codex
#
# Log file: /tmp/fish_msg_monitor/<agent>_log
# State file: /tmp/fish_msg_monitor/<agent>_seen

set -l MSG_ROOT "$HOME/Projects/messages"
set -l STATE_DIR "/tmp/fish_msg_monitor"
command mkdir -p $STATE_DIR

set -l agent $argv[1]
set -l interval $argv[2] 2>/dev/null; or set interval 10

if test -z "$agent"
    echo "Usage: msg-monitor <agent> [interval_seconds]"
    echo "Agents: hermes, claude1, claude2, codex"
    exit 1
end

set -g _MM_LOG_FILE "$STATE_DIR/$agent""_log"
set -l state_file "$STATE_DIR/$agent""_seen"
set -l senders hermes claude1 claude2 codex

# Build inbox list
set -l inboxes
for sender in $senders
    set -l dir "$MSG_ROOT/$sender""_to_$agent"
    if test -d $dir
        set inboxes $inboxes $dir
    end
end

if test -z "$inboxes"
    echo "ERROR: No inboxes found for agent '$agent'" >> $_MM_LOG_FILE
    exit 1
end

# List all .md/.txt files in inboxes
function _list_files
    for dir in $argv
        if test -d $dir
            command find $dir -maxdepth 1 -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null
        end
    end | sort -u
end

# Init: mark existing files as seen
if not test -f $state_file
    _list_files $inboxes > $state_file
    set -l count (wc -l < $state_file | string trim)
    echo "monitor started — $count existing messages marked as seen" >> $_MM_LOG_FILE
end

# Notify format
function _notify
    set -l file $argv[1]
    if not test -f $file
        return
    end
    set -l dir_name (basename (dirname $file))
    set -l sender (string replace -r '_to_.*' '' $dir_name | string replace -a '_' ' ')
    set -l title (head -1 $file 2>/dev/null | string replace -r '^# ' '')
    echo "NEW from $sender: $title — read: $file" >> $_MM_LOG_FILE
end

echo "Watching $agent every $interval s — log: $_MM_LOG_FILE" >> $_MM_LOG_FILE

# Main loop
while true
    set -l tmp (mktemp)
    set -l tmp_sorted (mktemp)
    _list_files $inboxes > $tmp
    sort -u $tmp > $tmp_sorted

    set -l tmp_seen (mktemp)
    sort -u $state_file > $tmp_seen

    set -l new_files (comm -13 $tmp_seen $tmp_sorted 2>/dev/null)
    command rm -f $tmp $tmp_sorted $tmp_seen

    if test -n "$new_files"
        for f in $new_files
            _notify $f
        end
        # Update state
        _list_files $inboxes | sort -u > $state_file
    end

    sleep $interval
end
