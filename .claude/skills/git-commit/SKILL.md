---
name: git-commit
description: "Create well-crafted git commits: analyze changes, write conventional commit messages, and stage files properly."
source: community
allowed-tools: "*"
user-invocable: true
---

# Git Commit Helper

Analyze staged changes and create well-structured git commits with conventional commit messages.

## STEP 1: ANALYZE CHANGES

Review the current git state:

- Check `git status` for staged, unstaged, and untracked files
- Read `git diff --staged` to understand what's being committed
- If nothing is staged, read `git diff` to understand what could be staged

## STEP 2: DETERMINE COMMIT STRATEGY

Based on the changes:

- Are these changes all related to one logical unit of work?
- Should they be split into multiple commits?
- Are there unrelated changes mixed in that should be separated?

If changes should be split:
- Identify logical groupings
- Stage and commit each group separately

## STEP 3: WRITE COMMIT MESSAGE

Follow conventional commit format:

```
type(scope): subject

[body]

[footer]
```

### Type
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `docs`: Documentation only
- `test`: Adding or updating tests
- `chore`: Maintenance (deps, config, build)
- `perf`: Performance improvement
- `ci`: CI/CD changes

### Rules
- Subject line: imperative mood, lowercase, no period, under 70 chars
- Body: explain WHAT and WHY (not HOW), wrap at 72 chars
- Footer: breaking changes, issue references

## STEP 4: STAGE AND COMMIT

- Stage the appropriate files (specific files, not `git add .`)
- Create the commit with the crafted message
- Verify the commit looks correct with `git log -1`

## STEP 5: REPORT

Confirm:
- What was committed (files and summary)
- The commit hash
- Any remaining unstaged changes
