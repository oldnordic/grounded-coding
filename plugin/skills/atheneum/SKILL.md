---
name: grounded-coding-atheneum
description: Curl reference for all atheneum/envoy HTTP endpoints. Use when MCP tools are unavailable or for direct HTTP access to knowledge, planning, handoff, ontology, and magellan bridge endpoints.
---

# Atheneum HTTP API — Curl Reference

Direct HTTP access to envoy/atheneum. Works when MCP is down. All endpoints at `http://127.0.0.1:9876`.

**Agent lifecycle (required):** Every session must register an agent before making API requests. Unregistered or retired agents get 401 Unauthorized. Register at session start, use the returned `agent_id` for all requests, retire when done. IDs are unique and never reused — each spawn gets a fresh identity.

```bash
# Register and capture agent ID
AGENT_ID=$(curl -sf -X POST http://127.0.0.1:9876/agents \
  -H "Content-Type: application/json" \
  -d '{"name":"session-name","kind":"claude"}' | jq -r '.agent_id')
# Use $AGENT_ID as X-Agent-Id for all subsequent requests
# When done:
curl -sf -H "X-Agent-Id: $AGENT_ID" -X POST "http://127.0.0.1:9876/agents/$AGENT_ID/retire"
```

---

## Guard Snippet

Paste this before any atheneum operations to test connectivity. `/health` does not require agent registration:

```bash
ENVOY_UP=$(curl -sf http://127.0.0.1:9876/health >/dev/null 2>&1 && echo "true" || echo "false")
```

When `$ENVOY_UP = "false"`, skip atheneum queries and proceed with graph tools only.

**MCP preference:** If `envoy_*` MCP tools appear in your tool list, prefer them for structured responses. Use curl as fallback when MCP is unavailable.

---

## Agent Coordination

### Health check (no registration required)
```bash
curl -sf http://127.0.0.1:9876/health
```
Returns: `{"status":"ok","uptime_secs":...,"agents_online":...}`

### Register agent (required before any other API call)
```bash
curl -sf -X POST http://127.0.0.1:9876/agents \
  -H "Content-Type: application/json" \
  -d '{"name":"claude1","kind":"worker"}'
```
Returns: `{"agent_id":"id1","name":"claude1","kind":"worker","lifecycle":"active",...}`
Use `agent_id` as the `X-Agent-Id` header for all subsequent requests.

### List agents
```bash
curl -sf -H "X-Agent-Id: {id}" http://127.0.0.1:9876/agents
```

### Retire agent (when session/subagent is done)
```bash
curl -sf -H "X-Agent-Id: {id}" -X POST http://127.0.0.1:9876/agents/{id}/retire
```
Returns: `{"retired":true,"affected":["id1","id1.1"]}`
Retired IDs are never reused. Descendants are also retired.

### Send message
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/messages \
  -H "Content-Type: application/json" \
  -d '{"type":"message","from":"claude1","to":"hermes","subject":"status","parts":[{"type":"text","content":"Task done"}]}'
```
For broadcasts (3+ recipients): comma-separate `to` field, e.g. `"to":"claude2,codex"`

### Poll unread messages
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/messages?to=claude1&limit=10"
```
Returns: `{"messages":[...],"has_more":false}`

### Get single message
```bash
curl -sf -H "X-Agent-Id: {agent}" http://127.0.0.1:9876/messages/{message_id}
```

### ACK message
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/messages/{message_id}/ack
```

---

## Knowledge Domain

### Query knowledge (discoveries + handoffs for a target)
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/knowledge?target=patch_symbol&project=myapp"
```
Returns: `{"target":"patch_symbol","discoveries":[...],"handoffs":[...],"token_savings":{...}}`

### Semantic search
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/search?q=CFG+analysis&k=5&project=myapp"
```
Returns: `{"results":[...],"total":...}`

### Store discovery
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/discoveries \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "claude1",
    "discovery_type": "Symbol",
    "target": "patch_symbol",
    "project_id":"myapp",
    "metadata": {"file": "src/edit/mod.rs", "line": 42, "complexity": 8}
  }'
```
Returns: `{"discovery_id":204,"agent":"claude1","target":"patch_symbol","discovery_type":"Symbol"}`

### List discoveries for a target
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/discoveries?target=patch_symbol&project=myapp"
```

---

## Planning Domain

### Create task
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Fix clippy lints","description":"Resolve Rust 1.95 warnings","project_id":"mirage"}'
```
Returns: `{"task_id":42,"status":"TODO"}`

### List tasks
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/tasks?project=myapp&status=IN_PROGRESS"
```
Returns: `{"tasks":[...]}`

### Get task details (with requirements + blockers)
```bash
curl -sf -H "X-Agent-Id: {agent}" http://127.0.0.1:9876/atheneum/tasks/42
```
Returns: `{"task":{...},"requirements":[...],"blockers":[...]}`

### Update task status
```bash
curl -sf -H "X-Agent-Id: {agent}" -X PATCH http://127.0.0.1:9876/atheneum/tasks/42/status \
  -H "Content-Type: application/json" \
  -d '{"status":"DONE"}'
```
Valid statuses: `TODO`, `IN_PROGRESS`, `DONE`, `BLOCKED`

### Add requirement to task
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/tasks/42/requirements \
  -H "Content-Type: application/json" \
  -d '{"statement":"All clippy warnings resolved","verification_method":"cargo clippy -- -D warnings"}'
```

### Add blocker to task
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/tasks/42/blockers \
  -H "Content-Type: application/json" \
  -d '{"description":"Upstream API change needed","blocker_type":"external"}'
```

---

## Handoff Domain

### Get pending handoff
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/handoffs/pending?agent=claude1&project=myapp"
```
Returns: `{"handoff":null}` or `{"handoff":{"id":7,"from_agent":"hermes","manifest":{...}}}`

### Claim handoff
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/handoffs/7/claim
```
Returns: `{"claimed":true,"handoff_id":7}`

### Create handoff
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/handoffs \
  -H "Content-Type: application/json" \
  -d '{"from_agent":"claude1","to_agent":"claude2","project_id":"myapp","manifest":{"status":"partial","files_changed":["src/edit/mod.rs"]}}'
```

---

## Ontology Domain

### List ontology classes
```bash
curl -sf -H "X-Agent-Id: {agent}" http://127.0.0.1:9876/atheneum/ontology/classes
```

### Create ontology class
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/ontology/classes \
  -H "Content-Type: application/json" \
  -d '{"name":"Service","description":"A deployed service component"}'
```

### List ontology properties
```bash
curl -sf -H "X-Agent-Id: {agent}" http://127.0.0.1:9876/atheneum/ontology/properties
```

### Create ontology property
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/ontology/properties \
  -H "Content-Type: application/json" \
  -d '{"name":"depends_on","domain_class":"Service","range_class":"Service","description":"Service dependency"}'
```

### Validate ontology edge
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/ontology/validate?from=Service&to=Service&edge=depends_on"
```

### Seed standard ontology
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/ontology/seed
```

---

## Magellan Bridge

### Import symbol from magellan DB
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/import-magellan/symbol \
  -H "Content-Type: application/json" \
  -d '{"magellan_db_path":"myapp","symbol_name":"patch_symbol","project_id":"myapp"}'
```
`magellan_db_path` accepts project name (auto-resolved) or full path.

### Import all symbols from magellan DB
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/import-magellan/all \
  -H "Content-Type: application/json" \
  -d '{"magellan_db_path":"myapp","project_id":"myapp","limit":100}'
```

### List discovered magellan DBs
```bash
curl -sf -H "X-Agent-Id: {agent}" http://127.0.0.1:9876/atheneum/import-magellan/dbs
```
Returns: `{"dbs":[{"project":"myapp","path":"~/Projects/forge/.magellan/forge.db"},...]}`

---

## Audit & Actions

### Record action
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/actions \
  -H "Content-Type: application/json" \
  -d '{"agent":"claude1","thought":"Fixed clippy lint in mirage","tool_calls":[{"tool_name":"Edit","args":{"file":"src/cfg/export.rs"}}]}'
```

### Query actions
```bash
curl -sf -H "X-Agent-Id: {agent}" "http://127.0.0.1:9876/atheneum/actions?agent=claude1&project=myapp"
```

---

## Journals

### Ingest journal entry
```bash
curl -sf -H "X-Agent-Id: {agent}" -X POST http://127.0.0.1:9876/atheneum/journals \
  -H "Content-Type: application/json" \
  -d '{"path":"journal/2026-05-19.md","content":"## Progress\nShipped clippy fixes for mirage and llmgrep","project_id":"myapp"}'
```
Returns: `{"section_ids":[...],"applied_kanban_updates":[...]}`

---

## MCP Equivalence Table

| MCP Tool | Curl Equivalent |
|----------|----------------|
| `envoy_status` | `GET /health` + `GET /agents` |
| `envoy_send` | `POST /messages` |
| `envoy_check` | `GET /messages?to={agent}` |
| `envoy_ack` | `POST /messages/{id}/ack` |
| `envoy_get` | `GET /messages/{id}` |
| `envoy_store_discovery` | `POST /atheneum/discoveries` |
| `envoy_query_knowledge` | `GET /atheneum/knowledge?target={sym}` |
| `envoy_search` | `GET /atheneum/search?q={query}` |
| `envoy_get_pending_handoff` | `GET /atheneum/handoffs/pending` |
| `envoy_claim_handoff` | `POST /atheneum/handoffs/{id}/claim` |
| `envoy_create_task` | `POST /atheneum/tasks` |
| `envoy_list_tasks` | `GET /atheneum/tasks` |
| `envoy_get_task` | `GET /atheneum/tasks/{id}` |
| `envoy_update_task_status` | `PATCH /atheneum/tasks/{id}/status` |
| `envoy_record_action` | `POST /atheneum/actions` |
| `envoy_get_actions` | `GET /atheneum/actions` |
| *(new)* retire agent | `POST /agents/{id}/retire` |
| `envoy_ontology_classes` | `GET/POST /atheneum/ontology/classes` |
| `envoy_ontology_properties` | `GET/POST /atheneum/ontology/properties` |
| `envoy_ontology_validate` | `GET /atheneum/ontology/validate` |
| `envoy_list_magellan_dbs` | `GET /atheneum/import-magellan/dbs` |
| `envoy_import_magellan_symbol` | `POST /atheneum/import-magellan/symbol` |
| `envoy_import_magellan_all` | `POST /atheneum/import-magellan/all` |
