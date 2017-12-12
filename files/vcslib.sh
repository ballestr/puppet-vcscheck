#!/bin/bash
## Managed by Puppet ##
# Function library for vcscheck
# From https://github.com/ballestr/puppet-vcscheck

## push status to a central collector
function vcsnotify() {
    local CONF=$1
    local MSGFILE=$2
    local VCSSRV

    ## post check file to the puppet host
    [ -s /etc/puppet/puppet.conf ] && VCSSRV=$(egrep "^[[:space:]]*server[[:space:]]*=" /etc/puppet/puppet.conf | sed -e "s/.*=\ *//")

    if [ "$2" = "OK" ]; then
        T=$(mktemp /tmp/vcscheck.XXXXXXXX) ## Chris: Cant send /dev/null with curl in CC7 ?
        [ "$VCSSRV" ] && curl -sS -F svncheck=@$T -Fconf=$CONF http://$VCSSRV/svncheck/submit.php > /dev/null
        rm $T
    else
        [ "$VCSSRV" ] && curl -sS -F svncheck=@$MSGFILE -Fconf=$CONF http://$VCSSRV/svncheck/submit.php > /dev/null
    fi
}

function vcs_checkstatus() {
    #echo vcs_checkstatus $TYPE
    case $TYPE in
        git) git_checkstatus;;
        svn) svn_checkstatus;;
        *) echo "Unknown type '$TYPE', aborting.";exit 1;;
    esac
}
function vcs_update() {
    case $TYPE in
        git) git_update;;
        svn) svn_update;;
        *) echo "Unknown type '$TYPE', aborting.";exit 1;;
    esac
}
function vcs_create() {
    case $TYPE in
        git) git_create;;
        svn) svn_create;;
        *) echo "Unknown type '$TYPE', aborting.";exit 1;;
    esac
}
function vcs_checkdir() {
    case $TYPE in
        git) git_checkdir;;
        svn) svn_checkdir;;
        *) echo "Unknown type '$TYPE', aborting.";exit 1;;
    esac
}
function vcs_isvcsdir() {
    case $TYPE in
        git) git_isvcsdir;;
        svn) svn_isvcsdir;;
        *) echo "Unknown type '$TYPE', aborting.";exit 1;;
    esac
}
function vcs_getsrc() {
    case $TYPE in
        git) git_getsrc;;
        svn) svn_getsrc;;
        *) echo "Unknown type '$TYPE', aborting.";exit 1;;
    esac
}

##################################################

function git_checkstatus() {
    local CHECK_LSTATUS=`git status --porcelain` 2>/dev/null
    local RL=${PIPESTATUS[0]}
    local CHECK_PSTATUS=`git status | egrep 'pull|push|ahead|detached'` 2>/dev/null
    #CHECK_PSTATUS=`git status --porcelain -b | egrep 'pull|push|ahead|no branch'` 2>/dev/null ## not yet supperted in SLC6 git 1.7.1
    local RP=${PIPESTATUS[0]}
    if [ "$VCSSRC" -a "$DO_REMOTE" ]; then
        local CHECK_FSTATUS=`git fetch --dry-run 2>&1`
        local RF=${PIPESTATUS[0]}
    else
        local CHECK_FSTATUS=""
    fi
    if [ "$CHECK_LSTATUS" == "" -a "$CHECK_PSTATUS" == "" -a "$CHECK_FSTATUS" == "" ]; then
        echo "## $CONF: $VCS_DIR git status OK, fetch OK, pull OK"
    elif [[ "$CHECK_FSTATUS" =~ "Network connection" ]]; then
        echo -e "## $CONF: network connection failure (s=$CHECK_STATUS):"
        echo $VCSSRC | sed -e 's/^/-- /'
        FAIL=1
    else
        echo -e "## $CONF: $VCS_DIR is not in sync or detached (r=$RL/$RP/$RF):"
        echo "--## git status :"
        git status 2>&1 | sed -e 's/^/-- /'
	if [ "$DO_REMOTE" ]; then
            if [ "$VCSSRC" ]; then
                echo "--## git fetch --dry-run :"
                git fetch --dry-run 2>&1 | sed -e 's/^/-- /'
            else
                echo "--## local repo, no check on git fetch"
            fi
        fi
        if git status | egrep -q 'Your branch is ahead' ; then
            ## Git 2.5+ (Q2 2015), the actual answer would be git log @{push} 
            echo "--## last commits (git show -10 --since='2 weeks' -s --oneline --decorate) :"
            git show -10 --since='2 weeks' -s --format='* %h [%ar]%d %an: %s' | sed -e 's/^/-- /'
            #git show -10 -s --oneline --decorate 2>&1 | sed -e 's/^/-- /'
        fi
        FAIL=1
    fi
    if [ -f .gitmodules ]; then
        local CHECK_SSTATUS
        CHECK_SSTATUS=`git submodule status --recursive| grep -v '^ '`
        CHECK_SSTATUS+=`git submodule foreach --recursive "git status|grep detached||true" | grep -B1 detached`
        RS=${PIPESTATUS[0]}
        if [ "$CHECK_SSTATUS" == "" ]; then
            echo "## $CONF: $VCS_DIR git submodule OK"
        else
            echo "## $CONF: $VCS_DIR git submodule status --recursive :"
            git submodule status --recursive 2>&1 | sed -e 's/^/-- /'
            echo "## $CONF: $VCS_DIR git submodule foreach --recursive git status :"
            git submodule foreach --recursive "git status" 2>&1 | sed -e 's/^/-- /'
            FAIL=1
        fi
    fi
}

function git_update() {
    local CHECK_LSTATUS=`git status --porcelain`
    if [ "$CHECK_LSTATUS" == "" ]; then
        local res=$(git fetch | grep -v "At revision")
        if [ "$res" ]; then
            echo "## $CONF: updated $VCS_DIR"
            echo "$res"
        fi
    else
        echo "## $CONF: unclean $VCS_DIR, skip update"
        echo "$res"
    fi
}

function git_create() {
    echo "## $CONF: git clone --depth=1 $SOURCE $VCS_DIR"
    git clone --depth=1 $SOURCE $VCS_DIR
}
function git_isvcsdir() {
    [ -e "$VCS_DIR" -a -e "$VCS_DIR/.git" ]
}
function git_checkdir() {
    if [ ! -e $VCS_DIR/.git ];  then
        echo "## $CONF: $VCS_DIR is not a GIT working directory."
        return 1
    fi
    if [ -e $VCS_DIR/.git/svn ]; then
        echo "## $CONF: $VCS_DIR is a GIT SVN working directory, not pure GIT."
        return 1
    fi
    return 0
}
function git_getsrc() {
    #VCSSRC=$(cd $VCS_DIR; git remote get-url origin) ## needs newer git
    VCSSRC=$(cd $VCS_DIR; git remote -v | grep origin | grep fetch | sed -e "s/origin\s*//" -e "s/\s*(.*)//" ) #" confused mcedit
}

#########################################

function svn_checkstatus() {
    local CHECK_STATUS
    if [ -n "$DO_REMOTE" ]; then
        CHECK_STATUS=`svn status -u 2>&1 | sed -e '/^Status/ d'` 2>/dev/null
        R=${PIPESTATUS[0]}
    else
        CHECK_STATUS=`svn status 2>&1 | sed -e '/^Status/ d'` 2>/dev/null
        R=${PIPESTATUS[0]}
    fi
    if [ "$CHECK_STATUS" == "" ]; then
        echo "## $CONF: $VCS_DIR status -u OK"
    elif [[ "$CHECK_STATUS" =~ "Network connection" ]]; then
        echo -e "## $CONF: network connection failure (s=$CHECK_STATUS):"
        svn info | grep "^Repository Root:" | sed -e 's/^/-- /'
        FAIL=1
    else
        echo -e "## $CONF: $VCS_DIR is not in sync (r=$R):"
        svn status -u 2>&1 | sed -e 's/^/-- /'
        FAIL=1
    fi
}

function svn_update() {
    res=$(svn update | egrep -v "^Updating|^At revision ")
    if [ "$res" ]; then
        echo "## $CONF: updated $VCS_DIR from $VCSSRC"
        echo "$res"
    fi
}

function svn_create() {
    echo "## $CONF: checkout $SOURCE $VCS_DIR"
    svn checkout $SOURCE $VCS_DIR
}
function svn_isvcsdir() {
    [ -e "$VCS_DIR" -a -e "$VCS_DIR/.svn" ]
}
function svn_checkdir() {
    if [ ! -d $VCS_DIR/.svn ];  then
        echo "## $CONF: $VCS_DIR is not an SVN working directory."
        return 1
    fi
}

function svn_getsrc() {
     #VCSSRC=$(cd $VCS_DIR; svn info)
    VCSSRC=$(cd $VCS_DIR; svn info | grep '^URL:' | cut -d' ' -f2)
    # OLD? VCSSRC=$(head .svn/entries | egrep "^svn.*:" | head -1)
}

#########################################

function gitsvn_checkdir() {
    if [ -e $VCS_DIR/.git/svn ];  then
        echo "## $CONF: $VCS_DIR is a GIT SVN working directory"
        VCSSRC=$(cd $VCS_DIR; git svn info)
    fi
}

function gitsvn_update() {
    # TODO: actually handle GIT checkouts (git svn rebase --dry-run not working as expected)
    true
}
