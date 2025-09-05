# Git Command Notes

### Issue: 'sed' command not found:
1. Reintall git
2. Add `C:\Program Files\Git\bin` to env paths.
3. Restart the terminal.

### Commit Changes
1. `git add .`
    - `git status` to list.
2. `git commit -m "<>"`
3. One time: `git remote add origin git remote add origin https://github.com/<your-username>/signal-extraction.git`
4. Now to push the code:
- One time: `git push -u origin main`
    - `-u` stands for `--set-upstream`
- Usual: `git push`

