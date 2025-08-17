#!/bin/bash

set -e

GOTIFY_URL="http://localhost:8080"
USERNAME="admin"
PASSWORD="admin"
RESULTS_DIR="vegeta_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

install_vegeta() {
    echo "Installing Vegeta..."
    
    if command -v brew >/dev/null 2>&1; then
        brew install vegeta
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y vegeta
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y vegeta
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S vegeta
    elif command -v pkg >/dev/null 2>&1; then
        sudo pkg install vegeta
    else
        echo "Installing Vegeta from GitHub releases..."
        ARCH=$(uname -m)
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            aarch64|arm64) ARCH="arm64" ;;
            i386|i686) ARCH="386" ;;
        esac
        
        VEGETA_VERSION="v12.11.1"
        VEGETA_URL="https://github.com/tsenart/vegeta/releases/download/${VEGETA_VERSION}/vegeta_${VEGETA_VERSION}_${OS}_${ARCH}.tar.gz"
        
        curl -L "$VEGETA_URL" | tar -xz
        sudo mv vegeta /usr/local/bin/
        chmod +x /usr/local/bin/vegeta
    fi
    
    echo "Vegeta installed successfully"
}

if ! command -v vegeta >/dev/null 2>&1; then
    install_vegeta
fi

mkdir -p "$RESULTS_DIR"

if ! curl -s "$GOTIFY_URL" > /dev/null; then
    echo "Gotify is not running at $GOTIFY_URL"
    exit 1
fi

APP_TOKEN=$(curl -s -X POST "$GOTIFY_URL/application" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{"name": "Vegeta Load Test", "description": "Load testing application"}' \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$APP_TOKEN" ]; then
    echo "Failed to create application token"
    exit 1
fi

run_load_test() {
    local test_name=$1
    local rate=$2
    local duration=$3
    local body_file=$4
    
    cat > "${RESULTS_DIR}/targets_${test_name}.txt" <<EOF
POST ${GOTIFY_URL}/message
X-Gotify-Key: ${APP_TOKEN}
Content-Type: application/json
@${body_file}
EOF
    
    vegeta attack \
        -targets="${RESULTS_DIR}/targets_${test_name}.txt" \
        -rate="$rate" \
        -duration="$duration" \
        -timeout=30s \
        -output="${RESULTS_DIR}/${test_name}_${TIMESTAMP}.bin"
    
    vegeta report "${RESULTS_DIR}/${test_name}_${TIMESTAMP}.bin" > "${RESULTS_DIR}/${test_name}_${TIMESTAMP}_report.txt"
    vegeta report -type=json "${RESULTS_DIR}/${test_name}_${TIMESTAMP}.bin" > "${RESULTS_DIR}/${test_name}_${TIMESTAMP}_report.json"
    vegeta plot -title="$test_name Load Test" "${RESULTS_DIR}/${test_name}_${TIMESTAMP}.bin" > "${RESULTS_DIR}/${test_name}_${TIMESTAMP}_plot.html"
    vegeta report -type="hist[0,10ms,50ms,100ms,500ms,1s,5s]" "${RESULTS_DIR}/${test_name}_${TIMESTAMP}.bin" > "${RESULTS_DIR}/${test_name}_${TIMESTAMP}_histogram.txt"
    
    head -10 "${RESULTS_DIR}/${test_name}_${TIMESTAMP}_report.txt"
}

cat > "${RESULTS_DIR}/small_message.json" <<EOF
{
    "title": "Small Test Message",
    "message": "This is a small test message for load testing.",
    "priority": 5
}
EOF

cat > "${RESULTS_DIR}/medium_message.json" <<EOF
{
    "title": "Medium Test Message",
    "message": "$(printf 'This is a medium test message with more content. %.0s' {1..50})",
    "priority": 5
}
EOF

cat > "${RESULTS_DIR}/large_message.json" <<EOF
{
    "title": "Large Test Message",
    "message": "$(printf 'This is a large test message with lots of content to test performance under load. %.0s' {1..200})",
    "priority": 8
}
EOF

run_load_test "light_load" "10/s" "30s" "${RESULTS_DIR}/small_message.json"
run_load_test "medium_load" "50/s" "60s" "${RESULTS_DIR}/medium_message.json"
run_load_test "heavy_load" "100/s" "30s" "${RESULTS_DIR}/small_message.json"
run_load_test "burst_test" "200/s" "10s" "${RESULTS_DIR}/small_message.json"
run_load_test "large_message_test" "20/s" "30s" "${RESULTS_DIR}/large_message.json"
run_load_test "stress_test" "0" "15s" "${RESULTS_DIR}/small_message.json"

cat > "${RESULTS_DIR}/combined_report_${TIMESTAMP}.txt" <<EOF
=== GOTIFY LOAD TEST SUMMARY ===
Test Date: $(date)
Gotify URL: $GOTIFY_URL

Test Scenarios:
1. Light Load: 10 req/s for 30s (small messages)
2. Medium Load: 50 req/s for 60s (medium messages)
3. Heavy Load: 100 req/s for 30s (small messages)
4. Burst Test: 200 req/s for 10s (small messages)
5. Large Message Test: 20 req/s for 30s (large messages)
6. Stress Test: Maximum rate for 15s (small messages)

=== DETAILED RESULTS ===

EOF

for test in light_load medium_load heavy_load burst_test large_message_test stress_test; do
    if [ -f "${RESULTS_DIR}/${test}_${TIMESTAMP}_report.txt" ]; then
        echo "=== $test ===" >> "${RESULTS_DIR}/combined_report_${TIMESTAMP}.txt"
        cat "${RESULTS_DIR}/${test}_${TIMESTAMP}_report.txt" >> "${RESULTS_DIR}/combined_report_${TIMESTAMP}.txt"
        echo "" >> "${RESULTS_DIR}/combined_report_${TIMESTAMP}.txt"
    fi
done

cat > "${RESULTS_DIR}/index_${TIMESTAMP}.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Gotify Load Test Results - $TIMESTAMP</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .test-section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .links { margin: 10px 0; }
        .links a { margin-right: 15px; padding: 5px 10px; background: #007cba; color: white; text-decoration: none; border-radius: 3px; }
        .links a:hover { background: #005a87; }
    </style>
</head>
<body>
    <h1>Gotify Load Test Results</h1>
    <p><strong>Test Date:</strong> $(date)</p>
    <p><strong>Gotify URL:</strong> $GOTIFY_URL</p>
    
    <div class="test-section">
        <h2>Light Load Test (10 req/s, 30s)</h2>
        <div class="links">
            <a href="light_load_${TIMESTAMP}_plot.html">View Plot</a>
            <a href="light_load_${TIMESTAMP}_report.txt">Text Report</a>
            <a href="light_load_${TIMESTAMP}_histogram.txt">Histogram</a>
        </div>
    </div>
    
    <div class="test-section">
        <h2>Medium Load Test (50 req/s, 60s)</h2>
        <div class="links">
            <a href="medium_load_${TIMESTAMP}_plot.html">View Plot</a>
            <a href="medium_load_${TIMESTAMP}_report.txt">Text Report</a>
            <a href="medium_load_${TIMESTAMP}_histogram.txt">Histogram</a>
        </div>
    </div>
    
    <div class="test-section">
        <h2>Heavy Load Test (100 req/s, 30s)</h2>
        <div class="links">
            <a href="heavy_load_${TIMESTAMP}_plot.html">View Plot</a>
            <a href="heavy_load_${TIMESTAMP}_report.txt">Text Report</a>
            <a href="heavy_load_${TIMESTAMP}_histogram.txt">Histogram</a>
        </div>
    </div>
    
    <div class="test-section">
        <h2>Burst Test (200 req/s, 10s)</h2>
        <div class="links">
            <a href="burst_test_${TIMESTAMP}_plot.html">View Plot</a>
            <a href="burst_test_${TIMESTAMP}_report.txt">Text Report</a>
            <a href="burst_test_${TIMESTAMP}_histogram.txt">Histogram</a>
        </div>
    </div>
    
    <div class="test-section">
        <h2>Large Message Test (20 req/s, 30s)</h2>
        <div class="links">
            <a href="large_message_test_${TIMESTAMP}_plot.html">View Plot</a>
            <a href="large_message_test_${TIMESTAMP}_report.txt">Text Report</a>
            <a href="large_message_test_${TIMESTAMP}_histogram.txt">Histogram</a>
        </div>
    </div>
    
    <div class="test-section">
        <h2>Stress Test (Max rate, 15s)</h2>
        <div class="links">
            <a href="stress_test_${TIMESTAMP}_plot.html">View Plot</a>
            <a href="stress_test_${TIMESTAMP}_report.txt">Text Report</a>
            <a href="stress_test_${TIMESTAMP}_histogram.txt">Histogram</a>
        </div>
    </div>
    
    <div class="test-section">
        <h2>Combined Reports</h2>
        <div class="links">
            <a href="combined_report_${TIMESTAMP}.txt">Combined Text Report</a>
        </div>
    </div>
</body>
</html>
EOF

rm -f "${RESULTS_DIR}/targets_"*.txt
rm -f "${RESULTS_DIR}/"*_message.json
