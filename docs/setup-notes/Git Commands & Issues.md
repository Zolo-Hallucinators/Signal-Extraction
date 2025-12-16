# Git Command Notes

### Issue: 'sed' command not found:
1. Reintall git
2. Add `C:\Program Files\Git\bin` to env paths.
3. Restart the terminal.

### Commit Changes
1. `git add .`
    - `git status` to list.
2. `git commit -m "<>"`
3. One time: `git remote add origin https://github.com/Zolo-Hallucinators/Signal-Extraction.git`
4. Now to push the code:
- One time: `git push -u origin main`
    - `-u` stands for `--set-upstream`
- Usual: `git push`

### Branching out
1. Check current branch: `git branch`
2. Fetch latest changes: `git pull origin main`
3. Create and switch to that branch: `git checkout -b <branch-name>`
4. Just switch to that branch: `git checkout <branch-name>`

### Pushing in new branch:
1. Make sure to change upstream, so that you can use `git push` directly: `git push -u origin <branch-name>`.
