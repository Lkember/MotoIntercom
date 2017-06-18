# MotoIntercom

To merge Development branch and master branch do the following: 
merge master into the development first so that if there are any conflicts, I can resolve in the development branch itself and my master remains clean.

(on branch development)$ git merge master
(resolve any merge conflicts if there are any)
git checkout master
git merge development (there won't be any conflicts now)

(https://stackoverflow.com/questions/14168677/merge-development-branch-with-master)
