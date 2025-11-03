# LocalMaurice

**Bridge your local tools and MCP servers to AgentMaurice**

LocalMaurice is a lightweight client application that connects your local environment to the AgentMaurice cloud platform. It enables AgentMaurice to discover and use local MCP (Model Context Protocol) servers, execute local tools, and run custom skills—all while maintaining complete control over what gets exposed.

## Features

### 🔌 **MCP Server Integration**
- **STDIO Servers**: Run Node.js, Python, or binary MCP servers locally
- **SSE Servers**: Connect to MCP servers via Server-Sent Events
- **Auto-discovery**: Automatically register available tools with AgentMaurice
- **Hot reload**: Changes to MCP servers are detected and updated

### 🛠️ **Built-in Shell MCP**
- Optional integrated shell server for executing local commands
- Secure sandboxing and command filtering
- Audit logging of all executed commands

### 🌐 **Flexible Transport**
- **LiveKit Transport** (default): Low-latency WebRTC data channels
- **MQTT Transport**: Lightweight pub/sub messaging for IoT and edge deployments
- Automatic reconnection and failover

### 📦 **Local Skills**
- Define custom skills with Python, Node.js, or Go
- Hot-reload skill manifests during development
- Environment variable injection and runtime configuration

### 📊 **Advanced Logging**
- Structured logging with JSON or console output
- Automatic log rotation and compression
- Per-instance logging with configurable levels
- Debug mode for troubleshooting

## Installation

### Download Pre-built Binaries

Download the latest release for your platform from [GitHub Releases](https://github.com/agentmaurice/localmaurice/releases):

**Linux (amd64)**
```bash
wget https://github.com/agentmaurice/localmaurice/releases/latest/download/localmaurice_linux_amd64.tar.gz
tar -xzf localmaurice_linux_amd64.tar.gz
sudo mv localmaurice /usr/local/bin/
```

**Linux (arm64)**
```bash
wget https://github.com/agentmaurice/localmaurice/releases/latest/download/localmaurice_linux_arm64.tar.gz
tar -xzf localmaurice_linux_arm64.tar.gz
sudo mv localmaurice /usr/local/bin/
```

**macOS (Intel)**
```bash
wget https://github.com/agentmaurice/localmaurice/releases/latest/download/localmaurice_darwin_amd64.tar.gz
tar -xzf localmaurice_darwin_amd64.tar.gz
sudo mv localmaurice /usr/local/bin/
```

**macOS (Apple Silicon)**
```bash
wget https://github.com/agentmaurice/localmaurice/releases/latest/download/localmaurice_darwin_arm64.tar.gz
tar -xzf localmaurice_darwin_arm64.tar.gz
sudo mv localmaurice /usr/local/bin/
```

**Windows (amd64)**
```powershell
# Download from: https://github.com/agentmaurice/localmaurice/releases/latest/download/localmaurice_windows_amd64.zip
# Extract and add to PATH
```

### Build from Source

```bash
git clone https://github.com/agentmaurice/chatserver.git
cd chatserver
go build -o localmaurice ./cmd/localmaurice
```

## Quick Start

### 1. Get Your API Key

First, obtain an API key from your AgentMaurice deployment:

```bash
# Using mauricecli (if installed)
mauricecli apikey create --name "My LocalMaurice Client"

# Or via the web dashboard
# Visit: https://your-maurice-instance.com/settings/api-keys
```

### 2. Create Configuration File

Create a `config.yaml` file:

```yaml
# API Configuration
api_url: "https://your-maurice-instance.com"
api_key: "your-api-key-here"
local_name: "my-laptop"  # Unique identifier for this client

# Transport: "livekit" (default) or "mqtt"
transport: "livekit"

# Logging
log:
  level: "info"           # debug, info, warn, error
  encoding: "console"     # console or json
  output_file: ""         # Empty = stdout only
  max_size_mb: 100
  max_backups: 3
  max_age_days: 7
  compress: true

# MCP Servers
stdio_servers:
  - name: "filesystem"
    config:
      executable_path: "/usr/local/bin/mcp-server-filesystem"
      arguments: ["--root", "/home/user/workspace"]
      env:
        - "NODE_ENV=production"
      server_type: "node"

  - name: "github"
    config:
      executable_path: "npx"
      arguments: ["-y", "@modelcontextprotocol/server-github"]
      env:
        - "GITHUB_TOKEN=ghp_your_token_here"
      server_type: "node"

sse_servers:
  - name: "remote-tools"
    config:
      server_url: "http://localhost:3000/sse"
      timeout: 30

# Optional: Built-in Shell MCP
mcp_shell:
  enabled: false  # Set to true to enable shell commands

# Optional: Local Skills
local_skills:
  - name: "code-analyzer"
    manifest_url: "file:///home/user/skills/analyzer/skill.yaml"
    entrypoint: "main.py"
    language: "python"
    active: true
    env:
      - "PYTHONPATH=/home/user/skills"
```

### 3. Run LocalMaurice

```bash
localmaurice serve --config config.yaml
```

Or use environment variables:

```bash
export LOCALMAURICE_API_URL="https://your-maurice-instance.com"
export LOCALMAURICE_API_KEY="your-api-key-here"
export LOCALMAURICE_LOCAL_NAME="my-laptop"

localmaurice serve
```

## Configuration

### Configuration File Locations

LocalMaurice searches for `config.yaml` in the following order:

1. Path specified via `--config` flag
2. `$LOCALMAURICE_CONFIG_DIR/config.yaml`
3. `$HOME/.localmaurice/config.yaml`
4. `./config.yaml` (current directory)
5. `./configs/config.yaml`
6. Directory where the binary is located
7. `./configs/` relative to binary directory

### Environment Variables

All configuration options can be overridden with environment variables using the prefix `LOCALMAURICE_`:

```bash
LOCALMAURICE_API_URL="https://api.maurice.ai"
LOCALMAURICE_API_KEY="sk-abc123..."
LOCALMAURICE_LOCAL_NAME="office-desktop"
LOCALMAURICE_TRANSPORT="mqtt"
LOCALMAURICE_LOG_LEVEL="debug"
```

Nested keys use underscores:
```bash
LOCALMAURICE_LOG_LEVEL="debug"
LOCALMAURICE_LOG_ENCODING="json"
LOCALMAURICE_MQTT_BROKER="tcp://broker.hivemq.com:1883"
```

### Command-line Flags

```bash
localmaurice serve [flags]

Flags:
  --config string          Config file path
  --apikey string          Global API key (overrides config)
  --log.level string       Log level: debug, info, warn, error (default "info")
  --log.encoding string    Log encoding: console, json (default "console")
  -h, --help              Help for serve
```

## Transport Options

### LiveKit Transport (Default)

Uses WebRTC for real-time, bidirectional communication with low latency.

```yaml
transport: "livekit"
# No additional configuration needed - auto-configured via API
```

**Pros:**
- Ultra-low latency (< 100ms)
- NAT traversal with STUN/TURN
- Encrypted by default (DTLS-SRTP)
- Ideal for interactive use cases

**Cons:**
- Requires WebRTC support
- More resource-intensive than MQTT

### MQTT Transport

Uses lightweight publish-subscribe messaging, ideal for IoT and edge devices.

```yaml
transport: "mqtt"

mqtt:
  enabled: true
  broker: "tcp://mqtt.maurice.ai:1883"
  qos: 1                # Quality of Service: 0, 1, or 2
  keep_alive: 60        # Keep alive interval in seconds
  client_id: ""         # Optional: auto-generated if empty
```

**Pros:**
- Extremely lightweight
- Works on constrained devices
- Better for intermittent connectivity
- Firewall-friendly (single TCP port)

**Cons:**
- Higher latency than LiveKit
- Requires MQTT broker

**MQTT with TLS:**
```yaml
mqtt:
  broker: "ssl://mqtt.maurice.ai:8883"
  # Add TLS certificates if needed
```

## MCP Server Configuration

### STDIO Servers (Node.js, Python, Binaries)

```yaml
stdio_servers:
  - name: "filesystem"
    config:
      executable_path: "npx"
      arguments: ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
      server_type: "node"
      env:
        - "NODE_OPTIONS=--max-old-space-size=4096"

  - name: "python-tools"
    config:
      executable_path: "python3"
      arguments: ["-m", "mcp_server_tools"]
      server_type: "python"
      env:
        - "PYTHONUNBUFFERED=1"

  - name: "custom-binary"
    config:
      executable_path: "/usr/local/bin/my-mcp-server"
      arguments: ["--mode", "stdio"]
      server_type: "other"
```

### SSE Servers (HTTP Server-Sent Events)

```yaml
sse_servers:
  - name: "cloud-service"
    config:
      server_url: "https://api.example.com/mcp/sse"
      timeout: 30
      headers:
        - "Authorization: Bearer token123"
        - "X-Custom-Header: value"
```

### Built-in Shell MCP

**⚠️ Security Warning**: Only enable if you understand the security implications!

```yaml
mcp_shell:
  enabled: true
  # Uses local_name as shell instance name
```

When enabled, AgentMaurice can execute shell commands on your local machine. All commands are logged for audit purposes.

**Best Practices:**
- Only enable on trusted deployments
- Monitor shell command logs
- Use in combination with firewall rules
- Consider using a restricted user account

## Local Skills

Skills are custom tools written in Python, Node.js, or Go that extend AgentMaurice's capabilities.

### Skill Configuration

```yaml
local_skills:
  - name: "image-processor"
    manifest_url: "file:///home/user/skills/image-processor/skill.yaml"
    entrypoint: "main.py"
    language: "python"
    active: true
    env:
      - "MODEL_PATH=/models/vision"
      - "MAX_IMAGE_SIZE=10485760"

  - name: "code-linter"
    manifest_url: "https://example.com/skills/linter/skill.yaml"
    entrypoint: "index.js"
    language: "nodejs"
    active: true
```

### Skill Manifest Example (`skill.yaml`)

```yaml
name: "Image Processor"
version: "1.0.0"
description: "Process and analyze images"

tools:
  - name: "resize_image"
    description: "Resize an image to specific dimensions"
    input_schema:
      type: "object"
      properties:
        path:
          type: "string"
          description: "Path to image file"
        width:
          type: "integer"
        height:
          type: "integer"
      required: ["path", "width", "height"]

  - name: "detect_objects"
    description: "Detect objects in an image using ML"
    input_schema:
      type: "object"
      properties:
        path:
          type: "string"
      required: ["path"]
```

## Use Cases

### 1. Development Environment Bridge

Connect your IDE, local files, and development tools to AgentMaurice:

```yaml
stdio_servers:
  - name: "filesystem"
    config:
      executable_path: "npx"
      arguments: ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
      server_type: "node"

  - name: "git"
    config:
      executable_path: "npx"
      arguments: ["-y", "@modelcontextprotocol/server-git"]
      server_type: "node"
```

Now AgentMaurice can read your code, analyze it, and suggest improvements.

### 2. Edge Device Integration

Run LocalMaurice on edge devices with MQTT transport:

```yaml
transport: "mqtt"
mqtt:
  broker: "tcp://edge-broker.local:1883"
  qos: 1
  keep_alive: 120

local_skills:
  - name: "sensor-reader"
    manifest_url: "file:///opt/skills/sensors/skill.yaml"
    entrypoint: "read_sensors.py"
    language: "python"
    active: true
```

### 3. Personal Assistant

Connect your personal documents and services:

```yaml
stdio_servers:
  - name: "google-drive"
    config:
      executable_path: "npx"
      arguments: ["-y", "@modelcontextprotocol/server-gdrive"]
      server_type: "node"
      env:
        - "GOOGLE_CLIENT_ID=your_client_id"
        - "GOOGLE_CLIENT_SECRET=your_secret"

  - name: "calendar"
    config:
      executable_path: "python3"
      arguments: ["-m", "mcp_google_calendar"]
      server_type: "python"
```

### 4. CI/CD Integration

Run as part of your build pipeline:

```bash
#!/bin/bash
# Deploy LocalMaurice in CI
export LOCALMAURICE_API_URL="$MAURICE_API"
export LOCALMAURICE_API_KEY="$CI_API_KEY"
export LOCALMAURICE_LOCAL_NAME="ci-runner-${CI_JOB_ID}"

localmaurice serve --config ci-config.yaml &
MAURICE_PID=$!

# Run your CI tasks with Maurice available
./run-tests.sh

# Cleanup
kill $MAURICE_PID
```

## Troubleshooting

### Check Connection

```bash
# Enable debug logging
localmaurice serve --log.level=debug

# Or via environment
LOCALMAURICE_LOG_LEVEL=debug localmaurice serve
```

### Common Issues

**Issue: "Failed to fetch LiveKit details"**
```
Solution:
1. Verify API URL is correct
2. Check API key is valid
3. Ensure network connectivity
4. Check firewall rules
```

**Issue: "MCP server failed to start"**
```
Solution:
1. Verify executable_path is correct
2. Check executable has execute permissions
3. Ensure all dependencies are installed (npm, python, etc.)
4. Check server logs for errors
```

**Issue: "MQTT connection failed"**
```
Solution:
1. Verify MQTT broker URL and port
2. Check broker is running and accessible
3. Verify credentials if using authentication
4. Check firewall allows TCP connection
```

### Log Files

When `log.output_file` is configured, logs are written to the specified file with automatic rotation:

```yaml
log:
  output_file: "/var/log/localmaurice/app.log"
  max_size_mb: 100      # Rotate after 100MB
  max_backups: 5        # Keep 5 old files
  max_age_days: 30      # Delete files older than 30 days
  compress: true        # Compress rotated files
```

### Debug Mode

Enable JSON logging for structured log analysis:

```yaml
log:
  level: "debug"
  encoding: "json"
  output_file: "debug.log"
```

Then analyze with jq:
```bash
cat debug.log | jq 'select(.level == "error")'
cat debug.log | jq 'select(.msg | contains("MCP"))'
```

## Security Considerations

1. **API Key Protection**: Never commit API keys to version control. Use environment variables or secure secrets management.

2. **MCP Server Sandboxing**: MCP servers run with the same permissions as LocalMaurice. Consider using a restricted user account.

3. **Shell Access**: Only enable `mcp_shell` if absolutely necessary and on trusted deployments.

4. **Network Security**: Use TLS/SSL for all connections (MQTT over SSL, HTTPS API endpoints).

5. **Skill Validation**: Review skill code before enabling, especially from third-party sources.

6. **Log Sensitive Data**: Avoid logging sensitive information. Configure log rotation to prevent disk fill.

## Performance Tuning

### Memory Usage

For resource-constrained environments:

```yaml
log:
  encoding: "console"     # JSON uses more memory
  max_size_mb: 50         # Smaller log files
  max_backups: 2          # Fewer backups

# Limit MCP servers
stdio_servers:
  - name: "essential-only"
    # Only run necessary servers
```

### Network Optimization

**For low-bandwidth environments** (use MQTT):
```yaml
transport: "mqtt"
mqtt:
  qos: 0  # Fire-and-forget (faster but less reliable)
```

**For high-performance** (use LiveKit):
```yaml
transport: "livekit"
# LiveKit auto-optimizes based on network conditions
```

## Updating

### Updating Binary

```bash
# Download latest release
wget https://github.com/agentmaurice/localmaurice/releases/latest/download/localmaurice_linux_amd64.tar.gz
tar -xzf localmaurice_linux_amd64.tar.gz
sudo mv localmaurice /usr/local/bin/

# Restart service
sudo systemctl restart localmaurice  # If using systemd
```

### Updating MCP Servers

```bash
# Update Node.js MCP servers
npm update -g @modelcontextprotocol/server-*

# Update Python MCP servers
pip install --upgrade mcp-server-*

# Restart LocalMaurice to pick up changes
```

## Running as a Service

### systemd (Linux)

Create `/etc/systemd/system/localmaurice.service`:

```ini
[Unit]
Description=LocalMaurice Client
After=network.target

[Service]
Type=simple
User=localmaurice
Group=localmaurice
WorkingDirectory=/opt/localmaurice
ExecStart=/usr/local/bin/localmaurice serve --config /etc/localmaurice/config.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable localmaurice
sudo systemctl start localmaurice
sudo systemctl status localmaurice
```

### launchd (macOS)

Create `~/Library/LaunchAgents/com.agentmaurice.localmaurice.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agentmaurice.localmaurice</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/localmaurice</string>
        <string>serve</string>
        <string>--config</string>
        <string>/Users/username/.localmaurice/config.yaml</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/username/.localmaurice/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/username/.localmaurice/stderr.log</string>
</dict>
</plist>
```

Load:
```bash
launchctl load ~/Library/LaunchAgents/com.agentmaurice.localmaurice.plist
launchctl start com.agentmaurice.localmaurice
```
