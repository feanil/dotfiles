---
name: pr-review-drafts
description: Build, update and submit draft (PENDING) GitHub pull request reviews through the API - stage inline comments, append to a draft that already exists, reply on a thread, pick line anchors, drop or reword a staged comment, edit the review body, and submit. Use whenever creating or changing PR review comments programmatically, or when a review needs to stay unsubmitted so a human can edit it first.
---

# Draft PR reviews over the GitHub API

**Build the review in GraphQL, anchored by line. Submit and edit it over REST.** That is the
whole approach. Everything here was exercised end to end on
[openedx/webhook-test-repo#19](https://github.com/openedx/webhook-test-repo/pull/19) on
2026-09-30, across four staged reviews.

## Before you post

A PENDING review is invisible to everyone but its author until submitted, which is the point:
it lets a human read and edit the whole thing first. So **posting is a separate decision from
drafting**. Draft the content somewhere reviewable, get an explicit go-ahead, then post. An
approval or a submit goes live instantly and cannot be taken back.

Check the project's own instructions for whose name the review goes out under and what needs
sign-off; this skill only covers the mechanics.

## What to call

| To do this | Use |
|---|---|
| Create the pending review, with its comments | `addPullRequestReview` (GraphQL), no `event` |
| Add a comment to an already-staged review | `addPullRequestReviewThread` (GraphQL) |
| Reply on an existing thread | `addPullRequestReviewThreadReply` (GraphQL) |
| List what is staged | `GET /pulls/<N>/reviews/<ID>/comments` |
| Drop one staged comment | `DELETE /pulls/comments/<COMMENT_ID>` |
| Reword one staged comment | drop it, then re-add it |
| Edit the review body | `PUT /pulls/<N>/reviews/<ID>` with `{"body": …}` |
| Submit | `POST /pulls/<N>/reviews/<ID>/events` with `{"event": "COMMENT"}` |

There is **no rebuild step**, and no `position` arithmetic. Both used to be necessary only
because REST cannot add a comment to a review that is already staged. GraphQL can, so a draft
is edited in place and a human's edits to it are never destroyed by a delete-and-recreate.

## Picking the line

GraphQL anchors by `line` + `side`: the **file line number**, not a diff offset.

- `side: RIGHT` with the new file's number, for added and context lines.
- `side: LEFT` with the **old** file's number, for a deleted line.
- `startLine` / `startSide` as well, for a multi-line range.
- The line must be part of the diff.

`scripts/anchors.py OWNER/REPO <N> [path-substring]` prints every commentable anchor as a
ready-to-use pair, so nothing has to be counted by hand:

```
$ python3 scripts/anchors.py openedx/some-repo 123 Makefile
=== Makefile  (modified)
  line=12    side=RIGHT   test: ## run the suite
  line=13    side=LEFT   -	uv run pytest
  line=13    side=RIGHT  +	pytest
```

The number it prints is the number the file uses, so there is nothing to verify afterwards.

**`position` is a different coordinate.** It is the offset from the file's first `@@`, and it
coincides with the line number only in a wholly new file. Never pass one as the other. If an
older draft records anchors as positions, walk the patch to convert:

```bash
gh api repos/OWNER/REPO/pulls/<N>/files --paginate \
  --jq '.[] | select(.filename=="path/to/file.py") | .patch' \
| python3 -c "import sys,re
ln=0
for i,l in enumerate(sys.stdin.read().split('\n')):
    if l.startswith('@@'): ln=int(re.search(r'\+(\d+)',l).group(1))-1; print(i,'HUNK',l[:60]); continue
    if not l.startswith('-'): ln+=1
    print(i, ln if not l.startswith('-') else '(del)', repr(l[:70]))"
```

The left column is the position, the middle one the `line` to pass instead.

## Creating the review

Get the PR's node ID, then stage the body and every comment in one call:

```bash
PR=$(gh api graphql -f query='
  query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){id}}}' \
  -F o=OWNER -F r=REPO -F n=<N> --jq .data.repository.pullRequest.id)

gh api graphql -f query='
mutation($pr:ID!,$body:String!){
  addPullRequestReview(input:{ pullRequestId:$pr, body:$body, threads:[
    {path:"path/to/file.py", line:42, side:RIGHT, body:"comment text"},
    {path:"other.py",        line:17, side:RIGHT, body:"another"}
  ]}){ pullRequestReview { id databaseId state } }
}' -F pr="$PR" -F body="Review summary."
```

`state` comes back `PENDING`. Keep both ids: `id` (`PRR_…`) for further GraphQL, `databaseId`
for every REST call in the table. For a long or multi-line body, put it in a file and pass
`-F body=@body.txt` rather than fighting shell quoting.

## Appending to a draft that already exists

This is the part REST cannot do:

```bash
gh api graphql -f query='
mutation($review:ID!,$body:String!){
  addPullRequestReviewThread(input:{
    pullRequestReviewId:$review, path:"path/to/file.py", line:42, side:RIGHT, body:$body
  }){ thread { comments(first:1){ nodes { databaseId state } } } }
}' -F review=PRR_… -F body="comment text"
```

## Replying on a thread

First get the thread ids. The query also returns each thread's first comment `databaseId`, so
ids recorded from REST map across:

```bash
gh api graphql -f query='
query($o:String!,$r:String!,$n:Int!){ repository(owner:$o,name:$r){ pullRequest(number:$n){
  reviews(last:10){ nodes { id state } }
  reviewThreads(last:50){ nodes { id path isResolved
    comments(first:1){ nodes { databaseId author{login} } } } }
} } }' -F o=OWNER -F r=REPO -F n=<N>
```

Then reply into the draft:

```bash
gh api graphql -f query='
mutation($review:ID!,$thread:ID!,$body:String!){
  addPullRequestReviewThreadReply(input:{
    pullRequestReviewId:$review, pullRequestReviewThreadId:$thread, body:$body
  }){ comment { databaseId state } }
}' -F review=PRR_… -F thread=PRRT_… -F body="reply text"
```

Every mutation returns the comment's `state`. It must read `PENDING`. If it ever reads
anything else, stop - something went live.

## Two traps, both measured

**A reply cannot be posted live by omitting `pullRequestReviewId`.** While a pending review is
open, GitHub attaches the reply to it either way.

**The REST reply endpoint fails while a draft is open.**
`POST /pulls/<N>/comments/<ID>/replies` returns
`422 … user_id can only have one pending review per pull request`. It succeeds only when no
pending review exists, and then publishes immediately inside a review of its own.

So if something genuinely has to go out live and alone, submit or delete the staged review
first - and treat that as its own decision needing its own go-ahead.

## Submitting

```bash
gh api repos/OWNER/REPO/pulls/<N>/reviews/<REVIEW_ID>/events -X POST -f event=COMMENT
```

This sends the body and every staged comment together as one review, whatever mix of calls
built it. `APPROVE` and `REQUEST_CHANGES` are the other events; both go live instantly, and
GitHub refuses either on your own PR.

## Before deleting anything

`DELETE` is permanent, and a human may have edited the text in the GitHub UI. Staged comments
404 on `GET` and `PATCH` of the per-comment path, so the review's own `comments` endpoint is
the only way to read the live text:

```bash
gh api "repos/OWNER/REPO/pulls/<N>/reviews/<REVIEW_ID>/comments?per_page=100"
```

Diff that against what was posted before dropping anything, and compare parsed JSON rather
than `--jq` strings - bodies contain newlines, so splitting `--jq` output on newlines silently
produces garbage. Assume they may be editing right now.
