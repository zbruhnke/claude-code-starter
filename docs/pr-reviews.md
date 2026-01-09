# Automatic PR/MR Reviews

Get AI-powered code reviews automatically on every pull request or merge request.

## Standalone Script

Review any branch from the command line:

```bash
# Review current branch vs main
./review-mr.sh

# Review specific branch
./review-mr.sh feature-auth

# Review against different base
./review-mr.sh feature-auth develop

# Review GitHub PR by number
./review-mr.sh --pr 123

# Output as markdown (for posting)
./review-mr.sh --format markdown > review.md
```

## GitHub Actions

Add automatic PR reviews to your GitHub repo:

```bash
# Copy the workflow
mkdir -p .github/workflows
cp .github/workflows/pr-review.yml your-repo/.github/workflows/

# Add your Anthropic API key to repo secrets
# Settings > Secrets > Actions > New repository secret
# Name: ANTHROPIC_API_KEY
```

Every PR will automatically get a Claude review as a comment:
- Runs on PR open, new commits, and reopen
- Updates existing comment instead of spamming
- Can be manually triggered for any PR

## GitLab CI

Add automatic MR reviews to your GitLab repo:

```yaml
# In your .gitlab-ci.yml
include:
  - local: 'ci/gitlab-mr-review.yml'

# Or copy the job directly from ci/gitlab-mr-review.yml
```

Required CI/CD variables:
- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `GITLAB_TOKEN` - GitLab token with `api` scope for posting comments

## Data & Privacy

When using automated PR/MR reviews, understand what's sent to Anthropic:

### What's Transmitted

- The diff of changed files
- File paths and names
- Commit messages
- PR/MR title and description

### What's NOT Transmitted

- Unchanged files (unless explicitly referenced)
- Repository secrets (unless they're in the diff)
- Git history beyond the current PR

### Recommendations for Sensitive Repos

- Review the workflow file before enabling
- Don't enable on repos with secrets in code (fix that first)
- Use environment-scoped secrets with minimal permissions
- Consider self-hosted runners for regulated environments
- Disable on forks if your repo is public

### Token Scopes (Least Privilege)

| Platform | Required Scopes |
|----------|-----------------|
| GitHub | `contents: read`, `pull-requests: write` |
| GitLab | `api` scope (required for MR comments) |

If your organization has data residency requirements, consult your security team before enabling automated reviews.

## Customizing Reviews

The review script uses Claude to analyze changes. You can customize the review focus by modifying `review-mr.sh` or the workflow file.

Common customizations:
- Focus on security issues only
- Check for specific patterns (TODO, FIXME)
- Enforce code style requirements
- Flag breaking changes

## Troubleshooting

**Reviews not posting:**
- Check API key is set correctly in secrets
- Verify token has required permissions
- Check workflow logs for errors

**Reviews are too verbose:**
- Modify the prompt in review-mr.sh
- Add context limits

**Reviews miss context:**
- The review only sees the diff by default
- For more context, modify the script to include related files
