#!/bin/bash
# Minimal one-shot web helper for first-run auth guidance.
# Serves a static page explaining how to complete `claude login`.
PORT="${1:-8080}"

HTML='<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AgentDock — First Run Setup</title>
  <style>
    body { font-family: monospace; max-width: 640px; margin: 4rem auto; padding: 1rem; background: #111; color: #eee; }
    h1 { color: #f90; }
    code { background: #222; padding: 2px 6px; border-radius: 3px; color: #7cf; }
    pre { background: #222; padding: 1rem; border-radius: 6px; overflow-x: auto; }
    .status { color: #f90; }
  </style>
</head>
<body>
  <h1>AgentDock — First Run</h1>
  <p class="status">Waiting for authentication...</p>
  <p>AgentDock needs a <strong>claude.ai</strong> account to run. Complete the login in the container terminal:</p>
  <pre>docker exec -it &lt;container&gt; claude login</pre>
  <p>Or attach to the running container and follow the URL printed in the logs.</p>
  <p>Once authenticated, the credentials are saved to your data volume and this step will not be required again.</p>
  <hr>
  <p>Check container logs: <code>docker logs &lt;container&gt; -f</code></p>
</body>
</html>'

while true; do
  { echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n$HTML"; } | nc -l -p "$PORT" -q 1 2>/dev/null || true
done
