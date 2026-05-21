#!/usr/bin/env fish

# sync-wiki.fish — Sync Logseq graph to reference wiki
# Usage: sync-wiki [journals|pages|kanban|all]
# Default: all

set LOGSEQ_GRAPH "$HOME/Documents/plans and ideas"
set REF_WIKI "$HOME/wiki"

function sync_journals
    echo "Syncing journals..."
    mkdir -p "$REF_WIKI/logseq/journals"

    for file in (find "$LOGSEQ_GRAPH/journals" -name "*.md" -type f)
        set basename (basename $file)
        cp "$file" "$REF_WIKI/logseq/journals/$basename"
    end

    echo "  → Journals synced"
end

function sync_pages
    echo "Syncing pages..."
    mkdir -p "$REF_WIKI/pages"

    for file in (find "$LOGSEQ_GRAPH/pages" -name "*.md" -type f)
        set basename (basename $file)
        cp "$file" "$REF_WIKI/pages/$basename"
    end

    echo "  → Pages synced"
end

function sync_kanban
    echo "Syncing kanban..."
    if test -f "$LOGSEQ_GRAPH/kanban.md"
        cp "$LOGSEQ_GRAPH/kanban.md" "$REF_WIKI/kanban.md"
        echo "  → Kanban synced"
    else
        echo "  → Kanban not found in Logseq graph"
    end
end

function sync_all
    sync_journals
    sync_pages
    sync_kanban
    echo ""
    echo "Sync complete!"
    echo "  Logseq graph: $LOGSEQ_GRAPH"
    echo "  Reference wiki: $REF_WIKI"
end

# Main
switch (echo $argv[1] | string lower)
    case journals
        sync_journals
    case pages
        sync_pages
    case kanban
        sync_kanban
    case all ''
        sync_all
    case '*'
        echo "Usage: sync-wiki [journals|pages|kanban|all]"
        exit 1
end
