## ppsplit Script — Canonical Source Rule

`bin/ppsplit.sh` is the **canonical version** of the extraction script. The same script is also embedded inside `services/Peace Pi Video Splitter - 3) Extract snippets from video.workflow/Contents/document.wflow` as the `COMMAND_STRING` value.

### When editing the script

1. **Always edit `bin/ppsplit.sh` first.**
2. After any change to `bin/ppsplit.sh`, immediately sync the corresponding change into the `COMMAND_STRING` in `document.wflow`.
3. When writing to the workflow XML, all shell special characters must be XML-escaped:
   - `&` → `&amp;`
   - `<` → `&lt;`
   - `>` → `&gt;`

## Workflow Info.plist — macOS 26 Compatibility

Each workflow bundle contains a `Contents/Info.plist` that declares the service metadata. The **source** Info.plists in `services/` still contain their original Automator-generated values. `install.command` patches the installed copies at deploy time to fix macOS 26 incompatibilities.

If you add a new workflow or regenerate an Info.plist, be aware of these known issues:

| Key | Source value | Problem | Fix applied by install.command |
|---|---|---|---|
| `NSServices.0.NSIconName` | `NSTouchBarMore` | Touch Bar icon removed in macOS 26; silently blocks service registration | Replace with `NSActionTemplate` |
| `NSServices.0.NSBackgroundSystemColorName` | `systemOrangeColor` | Not recognized on macOS 26; can interfere with registration | Remove the key |
| `NSServices.0.NSRequiredContext` | `{NSApplicationIdentifier: com.apple.finder}` | Blocks Quick Actions from appearing in macOS 26+ | Remove on macOS 26+; keep on older macOS to preserve Finder-only scoping |

`NSSendFileTypes` handles file-type filtering on all macOS versions and does not need to change.

---

### Intentional differences between ppsplit.sh and the workflow

The following differences are **deliberate** and must be preserved in the workflow — do not overwrite them when syncing:

| Location | ppsplit.sh | Workflow (keep as-is) |
|---|---|---|
| Missing CSV error | `echo` + `exit 1` | `osascript display dialog` + `exit 1` |
| Transitions | Set via `-t` CLI flag | Prompted via `osascript` dialog before processing |
| Start notification | Simple message, no timestamp | Message includes `$(date +"%l:%M %p")` |
| End notification | Simple message, no timestamp | Message includes `$(date +"%l:%M %p")` |
| Per-clip notification | None | `osascript display notification` per clip |
