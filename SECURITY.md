# Security and privacy

The supported public version is the latest GitHub Release, within its documented OS / Helper compatibility. Apple notarization checks a submitted package; it does not prove correctness of private-API gesture behavior.

The companion needs Accessibility to intercept the specific gesture event type. Source signature, process, build, OS and payload checks deliberately narrow what can be rewritten. It makes no network requests, bundles no official Mac Mouse Fix code and leaves official preferences unchanged.

For a vulnerability, use this repository's private vulnerability reporting feature when available. Do not put credentials, private diagnostics or exploit details in a public issue. General gesture bugs can use public issues after reviewing attachments. No response-time or security-support SLA is promised.

Review `status.json` before sharing: it contains the local executable path. Gesture exports contain timestamps and source PIDs even though they omit keystrokes, screenshots, window titles and clipboard data. Keep diagnostic files out of commits and release assets.
