# Plan: Consolidate edit, review, and changelist Commands

## Current State

| Command | What it does |
|---------|--------------|
| `changelist new` | Create P4 changelist with description + commit list |
| `changelist update` | Update description/commit list in existing changelist |
| `edit` | Open git-changed files for edit in a changelist |
| `review new` | `changelist new` + `edit` + add #review + shelve |
| `review update` | optionally `changelist update` + `edit` + shelve |

## Core Operations

The atomic operations are:
1. **Create** - Create a new changelist with description
2. **Update description** - Update the commit list in an existing changelist
3. **Edit** - Open git-changed files for edit in a changelist
4. **Shelve** - Shelve the changelist
5. **Add #review** - Add the #review keyword to trigger Swarm

## Proposed Unified Structure

Consolidate everything under `changelist` with optional action flags:

```
git p4son changelist new -m <message> [-b BASE] [ALIAS] [-f] [-n] [--edit] [--shelve] [--review]
git p4son changelist update <CL> [-b BASE] [-n] [--edit] [--shelve]
git p4son changelist edit <CL> [-b BASE] [-n]
git p4son changelist shelve <CL> [-n] [--review]
```

## How Current Commands Map to New Structure

| Current | New |
|---------|-----|
| `changelist new -m "msg"` | `changelist new -m "msg"` |
| `changelist update 123` | `changelist update 123` |
| `edit 123` | `changelist edit 123` |
| `review new -m "msg"` | `changelist new -m "msg" --edit --review --shelve` |
| `review update 123` | `changelist update 123 --edit --shelve` |
| `review update 123 -d` | `changelist update 123 --edit --shelve` (update always updates desc) |

## Flag Behavior

- `--edit`: Also open files for edit after create/update
- `--shelve`: Also shelve the changelist after edit
- `--review`: Add #review keyword (implies `--shelve`)

## Advantages

1. **Single mental model** - Everything is about managing a changelist
2. **Composable** - Mix and match what you need
3. **Discoverable** - `git p4son changelist -h` shows all operations
4. **Atomic commands available** - Can still do just `edit` or just `shelve`

## Disadvantages

1. **Longer commands** for common workflows (review new/update)
2. **Breaking change** for existing users

## Possible Mitigation

Keep `review` and `edit` as shorthand aliases during a deprecation period:
- `edit 123` = `changelist edit 123` (with deprecation warning)
- `review new` = `changelist new --edit --review --shelve` (with deprecation warning)
- `review update` = `changelist update --edit --shelve` (with deprecation warning)

## Implementation Steps

1. Add `--edit`, `--shelve`, `--review` flags to `changelist new`
2. Add `--edit`, `--shelve` flags to `changelist update`
3. Add `changelist edit` subcommand (move logic from edit.py)
4. Add `changelist shelve` subcommand with `--review` flag
5. Update `edit` command to print deprecation warning and call `changelist edit`
6. Update `review` command to print deprecation warning and call appropriate `changelist` subcommand
7. Update README and help text
8. (Future) Remove deprecated `edit` and `review` commands

## Files to Modify

- `git_p4son/cli.py` - Add new subparsers and flags
- `git_p4son/changelist.py` - Add edit and shelve subcommands, add flags to new/update
- `git_p4son/edit.py` - Add deprecation warning, delegate to changelist
- `git_p4son/review.py` - Add deprecation warning, delegate to changelist (or remove)
- `README.md` - Update documentation
