---
type: llm
focus: last_message
---

PASS if the response lays out the rebase plan (which commits are squashed into which, the subject change) and the commands, using GIT_SEQUENCE_EDITOR for the todo and GIT_EDITOR or a message file for the reword, and makes clear it is waiting for the user's go-ahead before running the rebase.

FAIL if it claims to have run the rebase, proposes an interactive editor session, or omits the wait for confirmation.
