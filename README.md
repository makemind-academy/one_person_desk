# one-person-desk

Every item carries its source, the ordering rule is printed, and one hat narrows the list.

Article: [why-this-is-on-top](https://makemind.dev/en/field/why-this-is-on-top)

## What is here

- `desk_server/` — Dart MCP server (`mcp_server` from pub.dev). It holds the data and the tools and serves the app's pages as `ui://` resources.
- `desk.mbd/` — the app as a folder of JSON: `manifest.json` and the pages under `ui/`. No build step.
- `captures/` — screenshots taken from AppPlayer by `verify.py`.
- `verify.py`, `verify.sh` — the check.

## Open it in AppPlayer

Add a server app with command `dart`, arguments `run bin/server.dart`, working directory `desk_server/`. The server serves its pages; the player draws them.

## Verify

```bash
bash verify.sh
```

Needs AppPlayer with the debug MCP on (see `tools/README.md`). The script builds what needs building, drives the player through the screens above, asserts the claim at the top of this file, and writes `captures/`.
