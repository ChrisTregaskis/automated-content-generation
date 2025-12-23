#!/bin/bash
# Export n8n workflows and credentials for version control

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Exporting n8n workflows..."
docker compose exec -T n8n n8n export:workflow --all --separate --output=/demo-data/workflows/

echo "Exporting n8n credentials..."
docker compose exec -T n8n n8n export:credentials --all --separate --output=/demo-data/credentials/

echo ""
echo "Export complete. Files saved to:"
echo "  - ./n8n/demo-data/workflows/"
echo "  - ./n8n/demo-data/credentials/"
echo ""
echo "To commit: git add ./n8n/demo-data && git commit -m 'Update n8n workflows'"
