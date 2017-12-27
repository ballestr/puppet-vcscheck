#!/bin/bash
PATH="$PWD/../files/:$PATH" #path to vcscheck
cloneopt=--shallow

cd work || exit

function update {
	local dir=$1
	local ver=$2
(
cd work1
echo "-> update $ver $PWD"
echo -e "work1 $ver\n\n---\n" > README.md
echo "work1 $ver" > workX.md
echo "work1" > work1.md
#git config -l
git add -A
git commit -m "work1-$ver" 
git push
git branch -a -v
)
}
function show {
	local dir=$1
	( 
		cd $dir; 
		echo "-> $PWD"
		git branch -a -v 
	)
}
## return current hash and branch
function gitstatus {
	(
		cd $1
		echo "$(git rev-parse --abbrev-ref HEAD) $(git log -n1 --oneline)"
	)
}

echo "########################## prepare"
{
rm -rf *
git init --bare bare1.git
git clone bare1.git work1/ ## non-shallow clone
update work1 1
} 2>&1 | sed 's/^/    /'

echo "########################## test 1: clean"
{
git clone $cloneopt bare1.git work2/ &>/dev/null
#show work2
## local check must return OK
vcscheck --local --exitcode work2 
[ $? -eq 0 ] || exit 1 ; echo "OK"
## remote check must return OK
vcscheck --exitcode work2
[ $? -eq 0 ] || exit 1 ; echo "OK"
## update check must return OK
vcscheck --exitcode --update work2
[ $? -eq 0 ] || exit 1 ; echo "OK"
## commit hash must be the same
[ "$(gitstatus work1)" = "$(gitstatus work2)" ] || exit 1
echo "OK final status"
} 2>&1 | sed 's/^/    /'
[ ${PIPESTATUS[0]} -eq 0 ] || { echo "########################## test1 failed"; exit 1; }

echo "########################## test 2: plain update"
{
update work1 2 &>/dev/null
#show work2
## local check must return OK
vcscheck --local --exitcode work2 
[ $? -eq 0 ] || exit 1; echo "OK"
## remote check must return WARN
vcscheck --exitcode work2
[ $? -eq 1 ] || exit 1; echo "OK"
## update check must return OK
vcscheck --exitcode --update work2
[ $? -eq 0 ] || exit 1; echo "OK"
#show work2
## commit hash must be the same
[ "$(gitstatus work1)" = "$(gitstatus work2)" ] || exit 1
echo "OK final status"
} 2>&1 | sed 's/^/    /'
[ ${PIPESTATUS[0]} -eq 0 ] || { echo "########################## test2 failed"; exit 1; }

echo "########################## test 3: non-conflicting local change"
{
update work1 3 &>/dev/null
echo "test3" > work2/test3
## remote check must return WARN
vcscheck --exitcode work2
[ $? -eq 1 ] || exit 1; echo "OK"
## update check must return WARN
vcscheck --exitcode --update work2
[ $? -eq 1 ] || exit 1; echo "OK"
#show work2
gitstatus work1
gitstatus work2
## commit hash must be the same
[ "$(gitstatus work1)" = "$(gitstatus work2)" ] || exit 1
echo "OK final status"
} 2>&1 | sed 's/^/    /'
[ ${PIPESTATUS[0]} -eq 0 ] || { echo "########################## test3 failed"; exit 1; }
rm -f work2/test3

echo "########################## test 4: conflicting local change"
{
update work1 4 &>/dev/null
echo "test4" >> work2/README.md
## remote check must return WARN
vcscheck --exitcode work2
[ $? -eq 1 ] || exit 1; echo "OK"
## update check must return WARN
vcscheck --exitcode --update work2
[ $? -eq 1 ] || exit 1; echo "OK"
#show work2
gitstatus work1
gitstatus work2
## commit hash must be different
[ "$(gitstatus work1)" != "$(gitstatus work2)" ] || exit 1
echo "OK final status"

} 2>&1 | sed 's/^/    /'
[ ${PIPESTATUS[0]} -eq 0 ] || { echo "########################## test4 failed"; exit 1; }

echo "########################## test 5: unmergeable diverged local change & commit"
{
rm -rf work2; git clone $cloneopt bare1.git work2/ &>/dev/null
update work1 5 &>/dev/null
(cd work2; echo "test5">>workX.md; git commit -m "test5" -a)
## local check must return WARN (ahead)
vcscheck --exitcode --local work2
[ $? -eq 1 ] || exit 1; echo "OK"
## remote check must return WARN
vcscheck --exitcode work2
[ $? -eq 1 ] || exit 1; echo "OK"
## update check must return WARN
vcscheck --exitcode --update work2
[ $? -eq 1 ] || exit 1; echo "OK"
#show work2
gitstatus work1
gitstatus work2
## commit hash must be different
[ "$(gitstatus work1)" != "$(gitstatus work2)" ] || exit 1
## work2 must still be on the local commit
[[ "$(gitstatus work2)" =~ " test5" ]] || exit 1
echo "OK final status"

} 2>&1 | sed 's/^/    /'
[ ${PIPESTATUS[0]} -eq 0 ] || { echo "########################## test5 failed"; exit 1; }
#exit 

echo "########################## test 6: mergeable diverged local change & commit"
{
rm -rf work2; git clone $cloneopt bare1.git work2/ &>/dev/null
update work1 6 &>/dev/null
(cd work2; echo "test6">>README.md; git commit -m "test6" -a)
## local check must return WARN (ahead)
vcscheck --exitcode --local work2
[ $? -eq 1 ] || exit 1; echo "OK"
## remote check must return WARN
vcscheck --exitcode work2
[ $? -eq 1 ] || exit 1; echo "OK"
## update check must return WARN
vcscheck --exitcode --update work2
[ $? -eq 1 ] || exit 1; echo "OK"
#show work2
gitstatus work1
gitstatus work2
## commit hash must be different
[ "$(gitstatus work1)" != "$(gitstatus work2)" ] || exit 1
## work2 must be on merge commit - no, we do not want risky auto-merge here
#[[ "$(gitstatus work2)" =~ " Merge " ]] || exit 1
## work2 must be on last local commit
#[[ "$(gitstatus work2)" =~ " test6" ]] || exit 1
echo "OK final status"

} 2>&1 | sed 's/^/    /'
[ ${PIPESTATUS[0]} -eq 0 ] || { echo "########################## test5 failed"; exit 1; }

echo "########################## all tests done"
exit 0
