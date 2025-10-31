# Git Repository Migration and History Cleanup

This guide provides a step-by-step recipe for migrating an existing local Git repository (e.g., copied from another system) to a new GitHub repository.

The main goal is to move the repository and simultaneously clean up the *entire* commit history, unifying the author/email and preserving the original commit dates.

## Prerequisites

* A local copy of your Git repository.
* `git` installed and configured with your correct user/email.
* `gh` (The GitHub CLI) installed and authenticated.

## Step 1: Transfer and Enter Repository

First, copy your project directory (which contains the `.git` folder) to your machine.

```bash
# Example using rsync
rsync -a /path/to/my-repo/ ~/Projects/my-repo/
````

Navigate into the project directory:

```bash
cd ~/Projects/my-repo
```

Remove origin:

```bash
git remote remove origin
```

## Step 2: Create and Push to GitHub

Use the GitHub CLI (`gh`) to create a new repository. This command will also set up your local `origin` remote and push your *current* (uncleaned) history to GitHub.

```bash
# Example for a public repo named 'my-repo'
gh repo create my-repo --public --source=. --remote=origin
```

## Step 3: Clean Commit History (Author & Date)

This is the main cleanup step. You will use an interactive rebase to rewrite every commit from the very beginning, setting a uniform author and fixing any date mismatches.

1.  Start the interactive rebase for all commits:

    ```bash
    git rebase -i --root --committer-date-is-author-date
    ```

2.  Your text editor will open. Change **every** line that says `pick` to `edit`. Save and close the file.

3.  The rebase will now stop at the first commit. You must now loop through every commit by running the following commands:

    ```bash
    orig_date=$(git show -s --format=%cI HEAD)
    GIT_AUTHOR_DATE="$orig_date" \
    GIT_COMMITTER_DATE="$orig_date" \
    git commit --amend --author="$(git config user.name) <$(git config user.email)>" --no-edit
    git rebase --continue
    ```

4.  **Repeat these commands** until the rebase is complete. This can take a long time if you have many commits.

## Step 4: Force-Push the Cleaned History

After the rebase, your local history is completely rewritten. You must now **force-push** this new history to GitHub, overwriting the "dirty" history you pushed in Step 2.

```bash
# --force is required because you rewrote history
git push --force -u origin main
```

If you have other branches or tags to migrate, you must clean them and push them with force as well:

```bash
git push --force -u origin --all
git push --force origin --tags
```

## Result

  * Your Git repository is successfully migrated to GitHub.
  * The commit history is clean, with a uniform author.
  * The original commit dates are preserved.