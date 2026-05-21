---
name: grounded-coding-perf
description: Measure envoy latency, throughput, and resource usage with reproducible benchmarks. Run when evaluating envoy performance, profiling P50/P95/P99 latency, load testing endpoints, or diagnosing slow response times. Covers wrk load testing, curl latency profiling, and perf-based resource analysis.
---

# Grounded Coding — Performance

**Measure, don't guess. Latency is truth.**

Quantitative benchmarking for the envoy HTTP service. Measures latency, throughput, and resource usage with reproducible commands.

**Important:** All bash blocks must be run with `bash` (not fish). Copy the script to a file and run `bash /tmp/envoy-perf.sh`, or use `bash -c '...'`.

---

## Prerequisites

```bash
for cmd in wrk perf jq pidstat; do
  echo -n "$cmd: "; command -v "$cmd" >/dev/null 2>&1 && echo "OK" || echo "MISSING"
done

# Install missing (Arch)
# sudo pacman -S wrk perf jq sysstat
# go install github.com/rakyll/hey@latest   # optional, adds hey to ~/go/bin/

# perf_event_paranoid must be <= 1 for perf stat
# echo 1 | sudo tee /proc/sys/kernel/perf_event_paranoid
```

**Envoy must be running.** Health and registration are public (no auth required):

```bash
curl -sf http://127.0.0.1:9876/health | jq .
```

If DOWN, start envoy first: `systemctl --user start envoy.service`

---

## One-Shot Benchmark Script

Save and run with `bash`. Covers all phases end-to-end.

```bash
cat > /tmp/envoy-perf.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

ENVOY_URL="http://127.0.0.1:9876"
REQUESTS=50
TMPDIR=$(mktemp -d)

# --- Registration ---
AGENT_ID=$(curl -sf -X POST "$ENVOY_URL/agents" \
  -H "Content-Type: application/json" \
  -d '{"name":"perf-bench","kind":"benchmark"}' | jq -r '.agent_id')
echo "Agent: $AGENT_ID"
trap "curl -sf -H \"X-Agent-Id: $AGENT_ID\" -X POST \"$ENVOY_URL/agents/$AGENT_ID/retire\" >/dev/null 2>&1" EXIT

# --- Phase 0: Health ---
echo ""
echo "=== Health ==="
curl -sf "$ENVOY_URL/health" | jq .

# --- Phase 1: Warmup ---
echo ""
echo "=== Warmup ==="
for i in $(seq 1 10); do
  curl -sf -o /dev/null -w "%{time_total}\n" -H "X-Agent-Id: $AGENT_ID" "$ENVOY_URL/health"
done
echo "Done"

# --- Phase 2: Latency Profiling ---
echo ""
echo "=== Latency Profiling ($REQUESTS req/endpoint) ==="
ENDPOINTS=(
  "health|GET|/health"
  "agents-list|GET|/agents"
  "stats|GET|/stats"
  "knowledge-search|POST|/knowledge/search|{\"query\":\"test\",\"limit\":5}"
)

for ep in "${ENDPOINTS[@]}"; do
  IFS='|' read -r label method path body <<< "$ep"
  outfile="$TMPDIR/${label}.csv"
  echo "time_connect,time_starttransfer,time_total" > "$outfile"
  for i in $(seq 1 "$REQUESTS"); do
    if [ "$method" = "POST" ]; then
      curl -sf -o /dev/null \
        -w "%{time_connect},%{time_starttransfer},%{time_total}\n" \
        -H "X-Agent-Id: $AGENT_ID" -H "Content-Type: application/json" \
        -d "$body" "$ENVOY_URL$path" >> "$outfile" 2>/dev/null || echo "0,0,0" >> "$outfile"
    else
      curl -sf -o /dev/null \
        -w "%{time_connect},%{time_starttransfer},%{time_total}\n" \
        -H "X-Agent-Id: $AGENT_ID" \
        "$ENVOY_URL$path" >> "$outfile" 2>/dev/null || echo "0,0,0" >> "$outfile"
    fi
  done
  echo "  $label"
done

echo ""
printf "%-20s %7s %7s %7s %7s\n" "Endpoint" "P50" "P95" "P99" "TTFB"
printf "%-20s %7s %7s %7s %7s\n" "--------" "ms" "ms" "ms" "ms"
for ep in "${ENDPOINTS[@]}"; do
  IFS='|' read -r label method path body <<< "$ep"
  f="$TMPDIR/${label}"
  tail -n +2 "${f}.csv" | awk -F',' '{print $3 * 1000}' | sort -n > "${f}_total.txt"
  tail -n +2 "${f}.csv" | awk -F',' '{print $2 * 1000}' | sort -n > "${f}_ttfb.txt"
  n=$(wc -l < "${f}_total.txt")
  p50_i=$(( n * 50 / 100 )); [ $p50_i -eq 0 ] && p50_i=1
  p95_i=$(( n * 95 / 100 )); [ $p95_i -eq 0 ] && p95_i=1
  p99_i=$(( n * 99 / 100 )); [ $p99_i -eq 0 ] && p99_i=1
  printf "%-20s %7s %7s %7s %7s\n" "$label" \
    "$(sed -n "${p50_i}p" "${f}_total.txt")" \
    "$(sed -n "${p95_i}p" "${f}_total.txt")" \
    "$(sed -n "${p99_i}p" "${f}_total.txt")" \
    "$(sed -n "${p50_i}p" "${f}_ttfb.txt")"
done

# --- Phase 3: Load Testing ---
echo ""
echo "=== Load Test 1: Baseline (4t/50c/15s) ==="
wrk -t4 -c50 -d15s --latency -H "X-Agent-Id: $AGENT_ID" "$ENVOY_URL/health"

echo ""
echo "=== Load Test 2: High concurrency (4t/100c/15s) ==="
wrk -t4 -c100 -d15s --latency -H "X-Agent-Id: $AGENT_ID" "$ENVOY_URL/health"

echo ""
echo "=== Load Test 3: Authenticated (2t/20c/10s) ==="
wrk -t2 -c20 -d10s --latency -H "X-Agent-Id: $AGENT_ID" "$ENVOY_URL/agents"

# --- Phase 4: Resource Profiling ---
echo ""
ENVOY_PID=$(lsof -i :9876 -t 2>/dev/null | head -1)
if [ -n "$ENVOY_PID" ] && [ -d "/proc/$ENVOY_PID" ]; then
  BEFORE_RSS=$(grep VmRSS "/proc/$ENVOY_PID/status" | awk '{print $2}')
  echo "=== Resource Profiling (PID $ENVOY_PID) ==="
  echo "Memory BEFORE: RSS=${BEFORE_RSS} kB"
  grep -E 'VmSize|Threads' "/proc/$ENVOY_PID/status"

  echo ""
  echo "Perf stat (15s, per-second output):"
  perf stat -p "$ENVOY_PID" -I 1000 sleep 15 2>&1 &
  PERF_PID=$!
  sleep 1
  wrk -t4 -c50 -d15s -H "X-Agent-Id: $AGENT_ID" "$ENVOY_URL/health" >/dev/null 2>&1
  wait $PERF_PID 2>/dev/null || true

  AFTER_RSS=$(grep VmRSS "/proc/$ENVOY_PID/status" | awk '{print $2}')
  echo ""
  echo "Memory AFTER: RSS=${AFTER_RSS} kB"
  echo "RSS delta: $(( AFTER_RSS - BEFORE_RSS )) kB"
fi

echo ""
echo "Raw data: $TMPDIR"
echo "=== Done ==="
SCRIPT

bash /tmp/envoy-perf.sh
```

---

## Individual Phase Commands

For running phases separately instead of the full script.

### Agent Registration

```bash
# Register (public endpoint, no auth needed)
AGENT_ID=$(curl -sf -X POST http://127.0.0.1:9876/agents \
  -H "Content-Type: application/json" \
  -d '{"name":"perf-bench","kind":"benchmark"}' | jq -r '.agent_id')

# Retire when done
curl -sf -H "X-Agent-Id: $AGENT_ID" -X POST "http://127.0.0.1:9876/agents/$AGENT_ID/retire"
```

### Quick latency check (single endpoint)

```bash
# 50 sequential requests, print P50/P95/P99
curl -sf -o /dev/null -w "%{time_total}\n" -H "X-Agent-Id: $AGENT_ID" \
  http://127.0.0.1:9876/health{,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,} 2>/dev/null \
  | sort -n | awk 'NR==int(NR==0?1:NR*0.50){print "P50:",$1*1000,"ms"} NR==int(NR*0.95){print "P95:",$1*1000,"ms"} NR==int(NR*0.99){print "P99:",$1*1000,"ms"}'
```

### Single wrk load test

```bash
wrk -t4 -c50 -d15s --latency -H "X-Agent-Id: $AGENT_ID" http://127.0.0.1:9876/health
```

### Memory snapshot

```bash
ENVOY_PID=$(lsof -i :9876 -t 2>/dev/null | head -1)
grep -E 'VmRSS|VmSize|Threads' "/proc/$ENVOY_PID/status"
```

### Perf stat (correct syntax: use sleep as workload)

```bash
# WRONG: perf stat -p $PID -d 15  (expects a command argument)
# RIGHT: perf stat -p $PID -I 1000 sleep 15  (per-second output for 15s)
perf stat -p "$ENVOY_PID" -I 1000 sleep 15 2>&1
```

---

## Baseline Reference (Ryzen 7800X3D, envoy release, 2026-05-21)

These are the numbers from the first benchmark run. Compare future runs against these.

| Metric | Value |
|--------|-------|
| Health P50 latency | 0.10 ms |
| Health P99 latency | 0.12 ms |
| Stats P50 latency | 0.21 ms |
| Baseline throughput (4t/50c) | 391K req/s |
| High concurrency (4t/100c) | 443K req/s |
| CPU under load | ~2.2 cores, 4.3 GHz |
| IPC | 1.1 |
| Branch miss rate | 4.8% |
| RSS baseline | 12.8 MB |
| RSS delta after 4.25M req | +16 kB (no leak) |
| Perf overhead | ~28% throughput reduction |

---

## Report Generation (Optional)

```bash
REPORT_DIR=".perf-reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/$(date +%Y-%m-%d-%H%M).md"
# Pipe benchmark output to report:
bash /tmp/envoy-perf.sh | tee "$REPORT_FILE"
echo "Report: $REPORT_FILE"
```

---

## Cross-References

- **`grounded-coding-atheneum`** — full endpoint reference for envoy
- **`grounded-coding-doctor`** — health checks (run first if envoy seems down)
- **`grounded-coding-tools`** — general toolchain reference
