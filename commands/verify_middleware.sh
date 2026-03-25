#!/bin/bash
# Verify Middleware Skills and Adapters Deliverables

echo "========================================"
echo "Middleware Deliverables Verification"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SKILLS_DIR="/home/rpi/Opensource/automotive-claude-code-agents/skills/middleware"
ADAPTERS_DIR="/home/rpi/Opensource/automotive-claude-code-agents/tools/adapters/middleware"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$1" = true ]; then
        echo -e "${GREEN}✓${NC} $2"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

echo "1. Checking Skills Directory"
echo "----------------------------"
check "$([ -d "$SKILLS_DIR" ] && echo true || echo false)" "Skills directory exists"

SKILLS=(
    "dds-middleware.yaml"
    "mqtt-middleware.yaml"
    "amqp-middleware.yaml"
    "ros2-dds-middleware.yaml"
    "coap-middleware.yaml"
    "opcua-middleware.yaml"
)

for skill in "${SKILLS[@]}"; do
    check "$([ -f "$SKILLS_DIR/$skill" ] && echo true || echo false)" "Skill: $skill"
done

check "$([ -f "$SKILLS_DIR/README.md" ] && echo true || echo false)" "Skills README.md"

echo ""
echo "2. Checking Adapters Directory"
echo "-------------------------------"
check "$([ -d "$ADAPTERS_DIR" ] && echo true || echo false)" "Adapters directory exists"

ADAPTERS=(
    "__init__.py"
    "dds_adapter.py"
    "mqtt_adapter.py"
    "amqp_adapter.py"
    "ros2_adapter.py"
    "coap_adapter.py"
    "opcua_adapter.py"
)

for adapter in "${ADAPTERS[@]}"; do
    check "$([ -f "$ADAPTERS_DIR/$adapter" ] && echo true || echo false)" "Adapter: $adapter"
done

check "$([ -f "$ADAPTERS_DIR/README.md" ] && echo true || echo false)" "Adapters README.md"
check "$([ -f "$ADAPTERS_DIR/INTEGRATION_EXAMPLE.md" ] && echo true || echo false)" "Integration example"

echo ""
echo "3. Checking Documentation"
echo "-------------------------"
check "$([ -f '/home/rpi/Opensource/automotive-claude-code-agents/MIDDLEWARE_DELIVERABLES.md' ] && echo true || echo false)" "Main deliverables doc"

echo ""
echo "4. Code Quality Checks"
echo "----------------------"

# Check Python syntax
for adapter in dds_adapter.py mqtt_adapter.py amqp_adapter.py ros2_adapter.py coap_adapter.py opcua_adapter.py; do
    if [ -f "$ADAPTERS_DIR/$adapter" ]; then
        if python3 -m py_compile "$ADAPTERS_DIR/$adapter" 2>/dev/null; then
            check true "Python syntax: $adapter"
        else
            check false "Python syntax: $adapter"
        fi
    fi
done

echo ""
echo "5. File Size Analysis"
echo "---------------------"

echo "Skills:"
for skill in "${SKILLS[@]}"; do
    if [ -f "$SKILLS_DIR/$skill" ]; then
        lines=$(wc -l < "$SKILLS_DIR/$skill")
        echo "  $skill: $lines lines"
    fi
done

echo ""
echo "Adapters:"
for adapter in dds_adapter.py mqtt_adapter.py amqp_adapter.py ros2_adapter.py coap_adapter.py opcua_adapter.py; do
    if [ -f "$ADAPTERS_DIR/$adapter" ]; then
        lines=$(wc -l < "$ADAPTERS_DIR/$adapter")
        echo "  $adapter: $lines lines"
    fi
done

echo ""
echo "6. Content Validation"
echo "---------------------"

# Check for key patterns in skills
check "$(grep -q 'DDS (Data Distribution Service)' $SKILLS_DIR/dds-middleware.yaml && echo true || echo false)" "DDS skill has correct content"
check "$(grep -q 'MQTT' $SKILLS_DIR/mqtt-middleware.yaml && echo true || echo false)" "MQTT skill has correct content"
check "$(grep -q 'AMQP' $SKILLS_DIR/amqp-middleware.yaml && echo true || echo false)" "AMQP skill has correct content"
check "$(grep -q 'ROS 2' $SKILLS_DIR/ros2-dds-middleware.yaml && echo true || echo false)" "ROS 2 skill has correct content"
check "$(grep -q 'CoAP' $SKILLS_DIR/coap-middleware.yaml && echo true || echo false)" "CoAP skill has correct content"
check "$(grep -q 'OPC UA' $SKILLS_DIR/opcua-middleware.yaml && echo true || echo false)" "OPC UA skill has correct content"

# Check for key patterns in adapters
check "$(grep -q 'class DDSAdapter' $ADAPTERS_DIR/dds_adapter.py && echo true || echo false)" "DDS adapter has class definition"
check "$(grep -q 'class MQTTAdapter' $ADAPTERS_DIR/mqtt_adapter.py && echo true || echo false)" "MQTT adapter has class definition"
check "$(grep -q 'class AMQPAdapter' $ADAPTERS_DIR/amqp_adapter.py && echo true || echo false)" "AMQP adapter has class definition"

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Total Checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $((TOTAL_CHECKS - PASSED_CHECKS))"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    exit 1
fi
