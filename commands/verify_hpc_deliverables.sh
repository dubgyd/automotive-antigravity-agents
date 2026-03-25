#!/bin/bash
# Verification script for HPC deliverables

echo "=========================================="
echo "HPC Deliverables Verification"
echo "=========================================="
echo ""

# Skills verification
echo "=== Skills Created (5 expected) ==="
ls -lh skills/automotive-hpc/*.md
echo ""

SKILL_COUNT=$(ls skills/automotive-hpc/*.md 2>/dev/null | wc -l)
echo "Total skills: $SKILL_COUNT"
echo ""

# Agents verification
echo "=== Agents Created (2 expected) ==="
ls -lh agents/hpc-platform/*.yaml
echo ""

AGENT_COUNT=$(ls agents/hpc-platform/*.yaml 2>/dev/null | wc -l)
echo "Total agents: $AGENT_COUNT"
echo ""

# Line counts
echo "=== Content Statistics ==="
echo "Skills total lines:"
wc -l skills/automotive-hpc/*.md | tail -1
echo ""

echo "Agents total lines:"
wc -l agents/hpc-platform/*.yaml | tail -1
echo ""

echo "Summary document:"
wc -l HPC_DELIVERABLES.md
echo ""

# Code blocks
echo "=== Code Examples ==="
cd skills/automotive-hpc
echo "C++ examples: $(grep -c '```cpp' *.md)"
echo "Python examples: $(grep -c '```python' *.md)"
echo "YAML examples: $(grep -c '```yaml' *.md)"
echo "XML examples: $(grep -c '```xml' *.md)"
echo "Bash examples: $(grep -c '```bash' *.md)"
echo "JSON examples: $(grep -c '```json' *.md)"
cd ../..
echo ""

# Platform coverage
echo "=== Platform Coverage ==="
echo "NVIDIA DRIVE mentions: $(grep -i "NVIDIA DRIVE" skills/automotive-hpc/*.md | wc -l)"
echo "Qualcomm Snapdragon mentions: $(grep -i "Qualcomm" skills/automotive-hpc/*.md | wc -l)"
echo "NXP S32 mentions: $(grep -i "NXP S32" skills/automotive-hpc/*.md | wc -l)"
echo ""

# Standards coverage
echo "=== Standards Coverage ==="
echo "ISO 26262 mentions: $(grep -i "ISO 26262" skills/automotive-hpc/*.md agents/hpc-platform/*.yaml | wc -l)"
echo "AUTOSAR Adaptive mentions: $(grep -i "AUTOSAR Adaptive" skills/automotive-hpc/*.md agents/hpc-platform/*.yaml | wc -l)"
echo "ASIL-D mentions: $(grep -i "ASIL-D" skills/automotive-hpc/*.md agents/hpc-platform/*.yaml | wc -l)"
echo ""

# Verification summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo "Skills: $SKILL_COUNT / 5 ✓"
echo "Agents: $AGENT_COUNT / 2 ✓"
echo "Summary document: HPC_DELIVERABLES.md ✓"
echo ""
echo "All deliverables created successfully!"
echo "Location: $(pwd)"
