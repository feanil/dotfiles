#!/bin/sh
# SessionStart hook: one line of work state from ~/workdesk, so a session
# knows what is overdue or waiting without loading the dashboard. Prints
# nothing when workdesk or uv is absent, so it is safe on every machine.
root="${WORKDESK_ROOT:-$HOME/workdesk}"
[ -x "$root/bin/wd" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0
"$root/bin/wd" --root "$root" status --oneline 2>/dev/null
# the learning scaffold: skills not yet in use, with what to say; empty once they are
"$root/bin/wd" --root "$root" coach 2>/dev/null
exit 0
