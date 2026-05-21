#!/usr/bin/env fish
# msg-check — one-shot inbox check. Silent when empty (watchdog pattern).
# Usage: msg-check <agent>

set -l MSG_ROOT "$HOME/Projects/messages"
set -l STATE_DIR "/tmp/fish_msg_monitor"
command mkdir -p $STATE_DIR

set -l agent $argv[1]

if test -z "$agent"
    echo "Usage: msg-check <agent>"
    exit 1
end

set -l state_file "$STATE_DIR/$agent""_seen"
set -l senders hermes claude1 claude2 codex

set -l inboxes
for sender in $senders
    set -l dir "$MSG_ROOT/$sender""_to_$agent"
    if test -d $dir
        set inboxes $inboxes $dir
    end
end

test -z "$inboxes" && exit 0

function _list_files
    for dir in $argv
        if test -d $dir
            command find $dir -maxdepth 1 -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null
        end
    end | sort -u
end

# Init silently
if not test -f $state_file
    _list_files $inboxes > $state_file
    exit 0
end

set -l tmp (mktemp)
set -l tmp_sorted (mktemp)
_list_files $inboxes > $tmp
sort -u $tmp > $tmp_sorted

set -l tmp_seen (mktemp)
sort -u $state_file > $tmp_seen

set -l new_files (comm -13 $tmp_seen $tmp_sorted 2>/dev/null)
command rm -f $tmp $tmp_sorted $tmp_seen

if test -n "$new_files"
    echo "NEW MESSAGES:"
    for f in $new_files
        set -l dir_name (basename (dirname $f))
        set -l sender (string replace -r '_to_.*' '' $dir_name | string replace -a '_' ' ')
        set -l title (head -1 $f 2>/dev/null | string replace -r '^# ' '')
        echo "  NEW from $sender: $title — read: $f"
    end
    _list_files $inboxes | sort -u > $state_file
end
