#!/bin/bash
# plane-workspace setup script
#
# Commands:
#   setup.sh init <cwd>                        — detect scope, return JSON
#   setup.sh run <config_json_file>            — write plane-workspace.json + generate agent
#   setup.sh connect <api_base> <token> <slug> — validate token, return user info + projects
#   setup.sh connect-save <config_json_file>   — fetch metadata, update configs, write .mcp.json

set -e

COMMAND=$1
shift

# ─── HELPERS ────────────────────────────────────────────────────────────────

find_plugin_dir() {
  SKILL=$(find "$HOME" -maxdepth 10 -name "SKILL.md" \
    -path "*/plane-workspace/skills/setup/*" 2>/dev/null | head -1)
  if [ -z "$SKILL" ]; then
    echo "ERROR: Could not find plane-workspace plugin installation" >&2
    exit 1
  fi
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
# Detects install scope. No API calls.
# Output: JSON { scope, base_path }

if [ "$COMMAND" = "init" ]; then
  CWD=${1:-$(pwd)}

  SCOPE_INFO=$(detect_scope "$CWD")
  SCOPE=$(echo "$SCOPE_INFO" | cut -d'|' -f1)
  BASE_PATH=$(echo "$SCOPE_INFO" | cut -d'|' -f2)

  python3 -c "
import json
print(json.dumps({
  'scope': '$SCOPE',
  'base_path': '$BASE_PATH'
}, indent=2))
"
fi

# ─── COMMAND: run ───────────────────────────────────────────────────────────
# Reads identity config, writes plane-workspace.json (identity only),
# generates personal agent file from role template.

if [ "$COMMAND" = "run" ]; then
  CONFIG_FILE=$1

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  CONFIG=$(cat "$CONFIG_FILE")

  BASE_PATH=$(echo "$CONFIG"   | python3 -c "import sys,json; print(json.load(sys.stdin)['base_path'])")
  SCOPE=$(echo "$CONFIG"       | python3 -c "import sys,json; print(json.load(sys.stdin)['scope'])")
  NAME=$(echo "$CONFIG"        | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['name'])")
  EMAIL=$(echo "$CONFIG"       | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['email'])")
  ROLE=$(echo "$CONFIG"        | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['role'])")
  ROLE_DESC=$(echo "$CONFIG"   | python3 -c "import sys,json; print(json.load(sys.stdin)['user'].get('role_description') or '')")
  AGENT_NAME=$(echo "$CONFIG"  | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['agent_name'])")
  WRITES_CODE=$(echo "$CONFIG" | python3 -c "import sys,json; print(str(json.load(sys.stdin)['user']['writes_code']).lower())")

  PLUGIN_DIR=$(find_plugin_dir)
  TEMPLATES_DIR="$PLUGIN_DIR/templates"
  TODAY=$(date +%Y-%m-%d)

  # Write plane-workspace.json (identity only — no plane connection yet)
  echo "-> Writing plane-workspace.json..."
  python3 - <<EOF
import json, os

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
        "plane_user_id": "",
        "writes_code": "$WRITES_CODE" == "true"
    },
    "plane": None,
    "projects": []
}

os.makedirs("$BASE_PATH", exist_ok=True)
out_path = os.path.join("$BASE_PATH", "plane-workspace.json")
with open(out_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Written: {out_path}")
EOF

  # Generate agent file from role template
  echo "-> Generating agent file..."
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
    "frontend":  "Frontend Engineer",
    "backend":   "Backend Engineer",
    "fullstack": "Full-Stack Engineer",
    "devops":    "DevOps Engineer",
    "qa":        "QA Engineer",
    "pm":        "Product Manager",
    "ea":        "Executive Assistant",
    "designer":  "Designer",
    "recruiter": "Recruiter",
    "other":     "$ROLE_DESC" or "Engineer"
}

role_title    = role_titles.get("$ROLE_LOWER", "$ROLE_LOWER".title())
agent_context = f"You are acting as **$AGENT_NAME**, a {role_title}."

replacements = {
    "{{AGENT_NAME}}":       "$AGENT_NAME",
    "{{AGENT_CONTEXT}}":    agent_context,
    "{{AGENT_ROLE_TITLE}}": role_title,
    "{{PLANE_USER_ID}}":    "",
    "{{OWNER_NAME}}":       "$AGENT_NAME",
    "{{CUSTOM_NOTES}}":     "",
}

for placeholder, value in replacements.items():
    content = content.replace(placeholder, value)

content = re.sub(r'\n{3,}', '\n\n', content)

agents_dir = os.path.join("$BASE_PATH", "agents")
os.makedirs(agents_dir, exist_ok=True)
out_path = os.path.join(agents_dir, "$AGENT_NAME.md")
with open(out_path, "w") as f:
    f.write(content)

print(f"Written: {out_path}")
EOF

  # Create memory directory
  mkdir -p "$BASE_PATH/user/memory"

  echo ""
  echo "Setup complete!"
  echo "   Agent:    $BASE_PATH/agents/$AGENT_NAME.md"
  echo "   Config:   $BASE_PATH/plane-workspace.json"
  echo "   Memory:   $BASE_PATH/user/memory/"
  echo "   Scope:    $SCOPE"
  echo ""
  echo "   Next: run /connect-plane to link your Plane workspace."
fi

# ─── COMMAND: connect ───────────────────────────────────────────────────────
# Validates API token and fetches the project list.
# Output: JSON { user_id, display_name, email, projects[] }

if [ "$COMMAND" = "connect" ]; then
  API_BASE=$1; TOKEN=$2; SLUG=$3

  if [ -z "$TOKEN" ] || [ -z "$SLUG" ]; then
    echo '{"error": "API token and workspace slug are required"}'
    exit 1
  fi

  # Validate token + fetch user info
  USER_RESP=$(curl -sf -H "X-Api-Key: $TOKEN" "$API_BASE/api/v1/users/me/" 2>/dev/null) || {
    echo '{"error": "Invalid token or connection failed. Check your token and API base URL."}'
    exit 1
  }

  USER_ID=$(echo "$USER_RESP"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
  USER_DISPLAY=$(echo "$USER_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('display_name',''))")
  USER_EMAIL=$(echo "$USER_RESP"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('email',''))")

  if [ -z "$USER_ID" ]; then
    echo '{"error": "Could not parse user info from token response"}'
    exit 1
  fi

  # Fetch project list
  PROJECTS_RESP=$(curl -sf -H "X-Api-Key: $TOKEN" \
    "$API_BASE/api/v1/workspaces/$SLUG/projects/?per_page=100" 2>/dev/null) || {
    echo '{"error": "Failed to fetch projects. Check your workspace slug."}'
    exit 1
  }

  python3 - <<EOF
import json, sys

projects_raw = json.loads('''$PROJECTS_RESP''')
results = projects_raw.get('results', projects_raw) if isinstance(projects_raw, dict) else projects_raw

projects = [
    {"identifier": p["identifier"], "name": p["name"], "id": p["id"]}
    for p in results
]

print(json.dumps({
    "user_id":      "$USER_ID",
    "display_name": "$USER_DISPLAY",
    "email":        "$USER_EMAIL",
    "projects":     projects
}, indent=2))
EOF
fi

# ─── COMMAND: connect-save ──────────────────────────────────────────────────
# Reads connect config, fetches states/labels/members for selected projects,
# updates plane-workspace.json with plane section + project metadata,
# writes .mcp.json.

if [ "$COMMAND" = "connect-save" ]; then
  CONFIG_FILE=$1

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  CONFIG=$(cat "$CONFIG_FILE")

  BASE_PATH=$(echo "$CONFIG"         | python3 -c "import sys,json; print(json.load(sys.stdin)['base_path'])")
  SCOPE=$(echo "$CONFIG"             | python3 -c "import sys,json; print(json.load(sys.stdin)['scope'])")
  API_BASE=$(echo "$CONFIG"          | python3 -c "import sys,json; print(json.load(sys.stdin)['api_base'])")
  TOKEN=$(echo "$CONFIG"             | python3 -c "import sys,json; print(json.load(sys.stdin)['api_token'])")
  SLUG=$(echo "$CONFIG"              | python3 -c "import sys,json; print(json.load(sys.stdin)['workspace_slug'])")
  PLANE_USER_ID=$(echo "$CONFIG"     | python3 -c "import sys,json; print(json.load(sys.stdin)['plane_user_id'])")
  SELECTED_PROJECTS=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('selected_projects', [])))")

  PLUGIN_DIR=$(find_plugin_dir)
  METADATA_DIR=$(mktemp -d)

  echo "-> Fetching project metadata..."
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

print(f"Fetched metadata for {len(projects)} project(s)")
EOF

  echo "-> Updating plane-workspace.json..."
  python3 - <<EOF
import json, os

def load_json(path):
    try:
        with open(path) as f:
            data = json.load(f)
            if isinstance(data, dict):
                return data.get('results', [])
            return data
    except:
        return []

projects_raw = json.loads('''$SELECTED_PROJECTS''')
metadata_dir = "$METADATA_DIR"

projects = []
for p in projects_raw:
    pid = p['id']
    states      = load_json(f"{metadata_dir}/{pid}_states.json")
    labels      = load_json(f"{metadata_dir}/{pid}_labels.json")
    members_raw = load_json(f"{metadata_dir}/{pid}_members.json")

    members = []
    for m in members_raw:
        member = m.get('member', m)
        members.append({
            "name":  member.get("display_name", ""),
            "id":    member.get("id", ""),
            "email": member.get("email", "")
        })

    projects.append({
        "identifier": p["identifier"],
        "id":         pid,
        "name":       p["name"],
        "repos":      p.get("repos", []),
        "states":     [{"name": s["name"], "id": s["id"], "group": s.get("group", "")} for s in states],
        "labels":     [{"name": l["name"], "id": l["id"], "color": l.get("color", "")} for l in labels],
        "members":    members
    })

# Merge into existing plane-workspace.json
ws_path = os.path.join("$BASE_PATH", "plane-workspace.json")
with open(ws_path) as f:
    ws = json.load(f)

ws["user"]["plane_user_id"] = "$PLANE_USER_ID"
ws["plane"] = {
    "workspace_slug": "$SLUG",
    "api_base":       "$API_BASE",
    "mcp_server":     "plane-claude-mcp"
}
ws["projects"] = projects

with open(ws_path, "w") as f:
    json.dump(ws, f, indent=2)

print(f"Updated: {ws_path}")
EOF

  # Patch agent file with real plane_user_id
  AGENT_NAME=$(python3 -c "
import json
with open('$BASE_PATH/plane-workspace.json') as f:
    print(json.load(f)['user']['agent_name'])
")

  AGENT_FILE="$BASE_PATH/agents/$AGENT_NAME.md"
  if [ -f "$AGENT_FILE" ]; then
    echo "-> Patching agent file with Plane user ID..."
    python3 - <<EOF
with open("$AGENT_FILE") as f:
    content = f.read()

# Replace empty plane_user_id placeholder
content = content.replace(
    "**Plane User ID**: ``",
    "**Plane User ID**: \`$PLANE_USER_ID\`"
)

with open("$AGENT_FILE", "w") as f:
    f.write(content)

print(f"Patched: $AGENT_FILE")
EOF
  fi

  # Write .mcp.json
  echo "-> Writing .mcp.json..."
  if [ "$SCOPE" = "local" ] || [ "$SCOPE" = "project" ]; then
    MCP_FILE="$(dirname "$BASE_PATH")/.mcp.json"
  else
    MCP_FILE="$HOME/.claude/.mcp.json"
  fi

  python3 - <<EOF
import json, os

mcp_file = "$MCP_FILE"

try:
    with open(mcp_file) as f:
        mcp = json.load(f)
except:
    mcp = {"mcpServers": {}}

mcp.setdefault("mcpServers", {})
mcp["mcpServers"]["plane-claude-mcp"] = {
    "command": "uvx",
    "args":    ["plane-mcp-server", "stdio"],
    "env": {
        "PLANE_API_KEY":        "$TOKEN",
        "PLANE_WORKSPACE_SLUG": "$SLUG",
        "PLANE_BASE_URL":       "$API_BASE"
    }
}

with open(mcp_file, "w") as f:
    json.dump(mcp, f, indent=2)

print(f"Written: {mcp_file}")
EOF

  # Cleanup
  rm -rf "$METADATA_DIR"

  echo ""
  echo "Plane connected!"
  echo "   Workspace: $SLUG"
  echo "   Config:    $BASE_PATH/plane-workspace.json"
  echo "   MCP:       $MCP_FILE"
fi
