#!/bin/bash
# plane-workspace setup script
# Usage:
#   setup.sh init <api_base> <api_token|""> <slug> <cwd>
#   setup.sh run <config_json_file>
#
# If api_token is empty or "-", MCP connection is skipped.

set -e

COMMAND=$1
shift

# ─── HELPERS ────────────────────────────────────────────────────────────────

py() { python3 -c "$1"; }

json_get() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print($2)"
}

find_plugin_dir() {
  SKILL=$(find "$HOME" -maxdepth 10 -name "SKILL.md" \
    -path "*/plane-workspace/skills/setup/*" 2>/dev/null | head -1)
  if [ -z "$SKILL" ]; then
    echo "ERROR: Could not find plane-workspace plugin installation" >&2
    exit 1
  fi
  # Everything up to and including plane-workspace/
  echo "$SKILL" | sed 's|/skills/setup/SKILL.md||'
}

detect_scope() {
  CWD=$1
  if grep -rq "plane-claude-mcp\|plane-claude-marketplace\|plane-workspace" \
      "$CWD/.claude/" "$CWD/.mcp.json" 2>/dev/null; then
    echo "local|$CWD/.claude"
  else
    PLUGIN_DIR=$(find_plugin_dir)
    CLAUDE_HOME=$(echo "$PLUGIN_DIR" | sed 's|/plugins/.*||')
    echo "user|$CLAUDE_HOME"
  fi
}

# ─── COMMAND: init ──────────────────────────────────────────────────────────
# Validates token, detects scope, fetches project list
# Output: JSON with scope, base_path, user info, and projects array

if [ "$COMMAND" = "init" ]; then
  API_BASE=$1; TOKEN=$2; SLUG=$3; CWD=$4

  # Always detect scope first
  SCOPE_INFO=$(detect_scope "$CWD")
  SCOPE=$(echo "$SCOPE_INFO" | cut -d'|' -f1)
  BASE_PATH=$(echo "$SCOPE_INFO" | cut -d'|' -f2)

  # Skip Plane connection if no token
  if [ -z "$TOKEN" ] || [ "$TOKEN" = "-" ]; then
    python3 -c "import json; print(json.dumps({
      'scope': '$SCOPE',
      'base_path': '$BASE_PATH',
      'user_id': '',
      'display_name': '',
      'email': '',
      'no_token': True,
      'projects': []
    }, indent=2))"
    exit 0
  fi

  # Validate token
  USER_RESP=$(curl -sf -H "X-Api-Key: $TOKEN" "$API_BASE/api/v1/users/me/" 2>/dev/null) || {
    echo '{"error": "Invalid token or connection failed"}'
    exit 1
  }

  USER_ID=$(echo "$USER_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
  USER_DISPLAY=$(echo "$USER_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('display_name',''))")
  USER_EMAIL=$(echo "$USER_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('email',''))")

  if [ -z "$USER_ID" ]; then
    echo '{"error": "Could not parse user info from response"}'
    exit 1
  fi

  # Fetch projects (names + identifiers only — lightweight)
  PROJECTS_RESP=$(curl -sf -H "X-Api-Key: $TOKEN" \
    "$API_BASE/api/v1/workspaces/$SLUG/projects/?per_page=100" 2>/dev/null) || {
    echo '{"error": "Failed to fetch projects"}'
    exit 1
  }

  # Output result as JSON
  python3 - <<EOF
import json, sys

projects_raw = json.loads('''$PROJECTS_RESP''')
results = projects_raw.get('results', projects_raw) if isinstance(projects_raw, dict) else projects_raw

projects = [
  {"identifier": p["identifier"], "name": p["name"], "id": p["id"]}
  for p in results
]

print(json.dumps({
  "scope": "$SCOPE",
  "base_path": "$BASE_PATH",
  "user_id": "$USER_ID",
  "display_name": "$USER_DISPLAY",
  "email": "$USER_EMAIL",
  "no_token": False,
  "projects": projects
}, indent=2))
EOF

fi

# ─── COMMAND: run ───────────────────────────────────────────────────────────
# Reads config JSON file, fetches metadata, writes all output files

if [ "$COMMAND" = "run" ]; then
  CONFIG_FILE=$1

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  CONFIG=$(cat "$CONFIG_FILE")

  # Extract config values
  BASE_PATH=$(echo "$CONFIG"     | python3 -c "import sys,json; print(json.load(sys.stdin)['base_path'])")
  SCOPE=$(echo "$CONFIG"         | python3 -c "import sys,json; print(json.load(sys.stdin)['scope'])")
  NAME=$(echo "$CONFIG"          | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['name'])")
  EMAIL=$(echo "$CONFIG"         | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['email'])")
  ROLE=$(echo "$CONFIG"          | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['role'])")
  ROLE_DESC=$(echo "$CONFIG"     | python3 -c "import sys,json; print(json.load(sys.stdin)['user'].get('role_description') or '')")
  AGENT_NAME=$(echo "$CONFIG"    | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['agent_name'])")
  WRITES_CODE=$(echo "$CONFIG"   | python3 -c "import sys,json; print(str(json.load(sys.stdin)['user']['writes_code']).lower())")
  PLANE_USER_ID=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['plane_user_id'])")
  SLUG=$(echo "$CONFIG"          | python3 -c "import sys,json; print(json.load(sys.stdin)['plane']['workspace_slug'])")
  API_BASE=$(echo "$CONFIG"      | python3 -c "import sys,json; print(json.load(sys.stdin)['plane']['api_base'])")
  TOKEN=$(echo "$CONFIG"         | python3 -c "import sys,json; print(json.load(sys.stdin)['plane'].get('api_token') or '')")
  HAS_TOKEN=$([ -n "$TOKEN" ] && echo "yes" || echo "no")
  SELECTED_PROJECTS=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('selected_projects', [])))")

  PLUGIN_DIR=$(find_plugin_dir)
  TEMPLATES_DIR="$PLUGIN_DIR/templates"
  MCP_TEMPLATE="$PLUGIN_DIR/mcp.json.template"

  METADATA_DIR=$(mktemp -d)

  if [ "$HAS_TOKEN" = "yes" ]; then
    echo "→ Fetching project metadata..."

    python3 - <<EOF
import json, subprocess, os

projects = json.loads('''$SELECTED_PROJECTS''')
procs = []

for p in projects:
    pid = p['id']
    for endpoint in ['states', 'labels', 'members']:
        url = f"$API_BASE/api/v1/workspaces/$SLUG/projects/{pid}/{endpoint}/"
        out_file = f"$METADATA_DIR/{pid}_{endpoint}.json"
        proc = subprocess.Popen(
            ['curl', '-sf', '-H', 'X-Api-Key: $TOKEN', url],
            stdout=open(out_file, 'w'), stderr=subprocess.DEVNULL
        )
        procs.append(proc)

for p in procs:
    p.wait()

print(f"Fetched metadata for {len(projects)} projects")
EOF
  else
    echo "→ Skipping project metadata (no API token)"
  fi

  # Build final plane-workspace.json
  echo "→ Writing plane-workspace.json..."
  TODAY=$(date +%Y-%m-%d)

  python3 - <<EOF
import json, os, sys
from datetime import date

projects_raw = json.loads('''$SELECTED_PROJECTS''')
metadata_dir = "$METADATA_DIR"

def load_json(path):
    try:
        with open(path) as f:
            data = json.load(f)
            if isinstance(data, dict):
                return data.get('results', [])
            return data
    except:
        return []

projects = []
for p in projects_raw:
    pid = p['id']
    states  = load_json(f"{metadata_dir}/{pid}_states.json")
    labels  = load_json(f"{metadata_dir}/{pid}_labels.json")
    members_raw = load_json(f"{metadata_dir}/{pid}_members.json")

    members = []
    for m in members_raw:
        member = m.get('member', m)
        members.append({
            "name": member.get("display_name", ""),
            "id": member.get("id", ""),
            "email": member.get("email", "")
        })

    projects.append({
        "identifier": p["identifier"],
        "id": pid,
        "name": p["name"],
        "repos": p.get("repos", []),
        "states": [{"name": s["name"], "id": s["id"], "group": s.get("group","")} for s in states],
        "labels": [{"name": l["name"], "id": l["id"], "color": l.get("color","")} for l in labels],
        "members": members
    })

config = {
    "_meta": {
        "setup_date": "$TODAY",
        "scope": "$SCOPE",
        "base_path": "$BASE_PATH"
    },
    "user": {
        "name": "$NAME",
        "email": "$EMAIL",
        "role": "$ROLE",
        "role_description": "$ROLE_DESC" or None,
        "agent_name": "$AGENT_NAME",
        "plane_user_id": "$PLANE_USER_ID",
        "writes_code": "$WRITES_CODE" == "true"
    },
    "plane": {
        "workspace_slug": "$SLUG",
        "api_base": "$API_BASE",
        "mcp_server": "plane-claude-mcp"
    },
    "projects": projects
}

os.makedirs("$BASE_PATH", exist_ok=True)
out_path = os.path.join("$BASE_PATH", "plane-workspace.json")
with open(out_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Written: {out_path}")
EOF

  # Update .mcp.json (only if token provided)
  MCP_FILE=""
  if [ "$HAS_TOKEN" = "yes" ]; then
    echo "→ Updating .mcp.json..."
    if [ "$SCOPE" = "local" ] || [ "$SCOPE" = "project" ]; then
      MCP_FILE="$(dirname "$BASE_PATH")/.mcp.json"
    else
      MCP_FILE="$BASE_PATH/.mcp.json"
    fi

    python3 - <<EOF
import json, os

mcp_file = "$MCP_FILE"

# Read existing or start fresh
try:
    with open(mcp_file) as f:
        mcp = json.load(f)
except:
    mcp = {"mcpServers": {}}

mcp.setdefault("mcpServers", {})
mcp["mcpServers"]["plane-claude-mcp"] = {
    "command": "uvx",
    "args": ["plane-mcp-server", "stdio"],
    "env": {
        "PLANE_API_KEY": "$TOKEN",
        "PLANE_WORKSPACE_SLUG": "$SLUG",
        "PLANE_BASE_URL": "$API_BASE"
    }
}

with open(mcp_file, "w") as f:
    json.dump(mcp, f, indent=2)

print(f"Updated: {mcp_file}")
EOF
  else
    echo "→ Skipping .mcp.json (no API token — add later with /setup)"
  fi

  # Generate agent file from template
  echo "→ Generating agent file..."
  ROLE_LOWER=$(echo "$ROLE" | tr '[:upper:]' '[:lower:]')
  TEMPLATE_FILE="$TEMPLATES_DIR/$ROLE_LOWER.md"

  if [ ! -f "$TEMPLATE_FILE" ]; then
    TEMPLATE_FILE="$TEMPLATES_DIR/other.md"
  fi

  python3 - <<EOF
import os, re

with open("$TEMPLATE_FILE") as f:
    content = f.read()

role_titles = {
    "frontend": "Frontend Engineer",
    "backend": "Backend Engineer",
    "fullstack": "Full-Stack Engineer",
    "devops": "DevOps Engineer",
    "qa": "QA Engineer",
    "pm": "Product Manager",
    "ea": "Executive Assistant",
    "designer": "Designer",
    "recruiter": "Recruiter",
    "other": "$ROLE_DESC" or "Engineer"
}

role_title = role_titles.get("$ROLE_LOWER", "$ROLE_LOWER".title())
agent_context = f"You are acting as **$AGENT_NAME**, a {role_title}."

replacements = {
    "{{AGENT_NAME}}": "$AGENT_NAME",
    "{{AGENT_CONTEXT}}": agent_context,
    "{{AGENT_ROLE_TITLE}}": role_title,
    "{{PLANE_USER_ID}}": "$PLANE_USER_ID",
    "{{OWNER_NAME}}": "$AGENT_NAME",
    "{{CUSTOM_NOTES}}": "",
}

for placeholder, value in replacements.items():
    content = content.replace(placeholder, value)

# Remove empty CUSTOM_NOTES line
content = re.sub(r'\n\n\n+', '\n\n', content)

agents_dir = os.path.join("$BASE_PATH", "agents")
os.makedirs(agents_dir, exist_ok=True)
out_path = os.path.join(agents_dir, "$AGENT_NAME.md")
with open(out_path, "w") as f:
    f.write(content)

print(f"Written: {out_path}")
EOF

  # Cleanup
  rm -rf "$METADATA_DIR"

  echo ""
  echo "✅ Setup complete!"
  echo "   Agent:    $BASE_PATH/agents/$AGENT_NAME.md"
  echo "   Config:   $BASE_PATH/plane-workspace.json"
  if [ -n "$MCP_FILE" ]; then
    echo "   MCP:      $MCP_FILE"
  else
    echo "   MCP:      (not configured — run /setup again to add API token)"
  fi
  echo "   Scope:    $SCOPE"

fi
