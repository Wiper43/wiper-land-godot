Testing GitHub connection.

1️⃣ Make sure your current work is saved first
git add .
git commit -m "Save progress before creating new branch"
git push

This prevents losing any work.

2️⃣ Switch to the branch you want to branch from

For example, if you want the new branch to start from your current combat work:

git checkout phase2-combat

If you want it to start from main instead:

git checkout main
3️⃣ Create the new branch

Example branch name:

git checkout -b phase2-destructible-blocks

This command does two things at once:

creates branch
AND
switches to it
4️⃣ Push the new branch to GitHub

The first time you push a new branch you must link it:

git push -u origin phase2-destructible-blocks

After this, future pushes are just:

git push

//RUN GAME COMMAND
 npm dev run

 
///////////////////////////////////////////////////////
This resets everything to a clean repo state.

git reset --hard
git clean -fd

Basically restores the repo exactly to the commit.