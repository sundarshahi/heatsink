# Shared bats helpers. Every test sources this.
HS_REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HS="$HS_REPO/bin/heatsink"
FIXTURES="$HS_REPO/tests/fixtures"
export HS HS_REPO FIXTURES
