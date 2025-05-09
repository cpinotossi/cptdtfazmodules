# cptdtfazmodules

## Misc

### Git

~~~powershell
$prefix = "cptdtfazmodules"
gh repo create $prefix --public
git init
git remote add origin https://github.com/cpinotossi/$prefix.git
git status
git add .
git commit -m "Initial commit"
git push -u origin main
~~~