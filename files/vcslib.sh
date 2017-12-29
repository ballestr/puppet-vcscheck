#!/bin/bash
## Managed by Puppet ##
## puppetfile: modules/vcscheck/vcslib.sh
#
# Function library for vcscheck
# From https://github.com/ballestr/puppet-vcscheck

## push status to a central collector
function vcsnotify() {
    local CONF=$1
    local MSGFILE=$2

    ## post check file to the puppet host
    #[ -s /etc/puppet/puppet.conf ] && VCSSRV=$(egrep "^[[:space:]]*server[[:space:]]*=" /etc/puppet/puppet.conf | sed -e "s/.*=\ *//")
    #local URL="http://$VCSSRV/gather/vcscheck/submit.php"
    [ "$NOTIFYURL" ] || { return 1; }

    if [ "$2" = "OK" ]; then
        local T=$(mktemp /var/tmp/vcscheck.XXXXXXXX) ## Chris: Cant send /dev/null with curl in CC7 ? # sash: /dev/null ok on Debian curl 7.38.0 
        curl -sS -F vcscheck=@$T -Fconf=$CONF $NOTIFYURL > /dev/null
        local R=$?
        rm $T
    else
        curl -sS -F vcscheck=@$MSGFILE -Fconf=$CONF $NOTIFYURL > /dev/null
        local R=$?
    fi
    #echo ".. vcsnotify $CONF $MSGFILE R=$R [$NOTIFYURL]" #DEBUG
    return $R
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

function git_prefetch() {
    if [ "$VCSSRC" -a "$DO_REMOTE" ]; then
        ## let's try to do a plain, safe fetch, no --all nor --prune
        local CHECK_FSTATUS=`git fetch 2>&1`
        local RF=${PIPESTATUS[0]}
    else
        local CHECK_FSTATUS=""
    fi
    if [[ "$CHECK_FSTATUS" =~ "Network connection" ]]; then
        echo -e "## $CONF: network connection failure (s=$CHECK_FSTATUS):"
        echo $VCSSRC | sed -e 's/^/-- /'
        FAIL=1
    fi
}

function git_checkstatus() {
    git_prefetch

    local CHECK_LSTATUS=`git status --porcelain` 2>/dev/null
    local RL=${PIPESTATUS[0]}
    local CHECK_PSTATUS=`git status | egrep 'pull|push|ahead|detached|diverged|any branch'` 2>/dev/null
    #CHECK_PSTATUS=`git status --porcelain -b | egrep 'pull|push|ahead|no branch'` 2>/dev/null ## not yet supperted in SLC6 git 1.7.1
    local RP=${PIPESTATUS[0]}
    if [ "$CHECK_LSTATUS" == "" -a "$CHECK_PSTATUS" == "" ]; then
        echo "## $CONF: $VCS_DIR git local clean/OK, sync OK"
    elif [ "$CHECK_LSTATUS" == "" ]; then
        echo "## $CONF: $VCS_DIR git local clean/OK, out of sync"
        LOCAL=0
        REMOTE=1
        FAIL=1
    else
        echo -e "## $CONF: $VCS_DIR is not in sync or detached (r=$RL/$RP):"
        LOCAL=1
        REMOTE=1
        FAIL=1
    fi
    if [ $FAIL -ne 0 ]; then
        echo "--## git status :"
        git status 2>&1 | egrep -v "^$|\(use " | sed -e 's/^/-- /'
        echo "--## git stash list :"
        git stash list 2>&1 | sed -e 's/^/-- /'
        if [ "$DO_REMOTE" ]; then
            if [ "$VCSSRC" ]; then
                echo "--## git fetch --dry-run :"
                git fetch --dry-run 2>&1 | sed -e 's/^/-- /'
            else
                echo "--## local repo, no check on git fetch"
            fi
        fi
        if git status | egrep -q 'Your branch is ahead|Your branch and' ; then
            ## Git 2.5+ (Q2 2015), the actual answer would be git log @{push} 
            echo "--## last commits (git show -10 --since='2 weeks' -s --oneline --decorate) :"
            git show -10 --since='2 weeks' -s --format='* %h [%ar]%d %ae: %s' | sed -e 's/^/-- /'
            #git show -10 -s --oneline --decorate 2>&1 | sed -e 's/^/-- /'
        fi
        FAIL=1
    fi
    ## check submodules
    if [ -f .gitmodules ]; then
        local CHECK_SSTATUS
        CHECK_SSTATUS=`git submodule status --recursive| grep -v '^ '`
        CHECK_SSTATUS+=`git submodule foreach --recursive "git status|egrep 'detached|ahead|any branch'||true" | egrep -B1 'detached|ahead'`
        RS=${PIPESTATUS[0]}
        if [ "$CHECK_SSTATUS" == "" ]; then
            echo "## $CONF: $VCS_DIR git submodule OK"
        else
            echo "## $CONF: $VCS_DIR git submodule status --recursive :"
            git submodule status --recursive 2>&1 | sed -e 's/^/-- /'
            echo "## $CONF: $VCS_DIR git submodule foreach --recursive git status :"
            git submodule foreach --recursive "git status" 2>&1 | \
                egrep -v "^$|\(use |working tree clean|branch is up-to-date|On branch master" | sed -e 's/^/-- /'
            FAIL=1
        fi
    fi
}

function git_update() {
    if [ -f .gitmodules ]; then
        substatus=$(git submodule status --recursive | grep -v "^ ")
        if [ "$substatus" ]; then
            echo "## $CONF: git submodule status --recursive (pre-pull) in $VCS_DIR"
            echo "$substatus"
        fi
    fi

    ## do not try to check status ourselves, let git take care
    ## conservatively use fast-forward-only, to avoid merge conflicts
    if [ "$(git remote)" ]; then
        local out=$(git pull --ff-only 2>&1 )
        R=${PIPESTATUS[0]}
        #echo "$out"
        if [ $R -ne 0 -o "$out" != "Already up-to-date." ]; then
            echo "## $CONF: updated $VCS_DIR res=$R"
            echo "$out"
        fi
    else
        echo "## $CONF: NOTICE no remote, skipping update"
    fi
    ## ToDo: test with submodules
    ## worried about merges with local...
    ## update --checkout creates detached heads :-(
    if [ -f .gitmodules ]; then
        subupdate=$(git submodule update --recursive)
        if [ "$subupdate" ]; then
            echo "## $CONF: git submodule update --recursive in $VCS_DIR"
            echo "$subupdate"
        fi
    fi
}

function git_create() {
    ## ToDo: should we clone shallow or not?
    echo "## $CONF: git clone --depth=1 $SOURCE $VCS_DIR"
    git clone --depth=1 $SOURCE $VCS_DIR
    if [ -f .gitmodules ]; then
        echo "## $CONF: git submodule init/update in $VCS_DIR"
        ## ToDo: we may need a loop for nested submodules
        git submodule init # no --recursive available here
        git submodule foreach --recursive git submodule init
        git submodule update --recursive
    fi
}
function git_isvcsdir() {
    [ -e "$VCS_DIR" -a -e "$VCS_DIR/.git" ]
}
function git_checkdir() {
    if [ ! -e $VCS_DIR/.git ];  then
        echo "## $CONF: ERROR: $VCS_DIR is not a GIT working directory."
        return 1
    fi
    if [ -e $VCS_DIR/.git/svn ]; then
        echo "## $CONF: ERROR: $VCS_DIR is a GIT SVN working directory, not pure GIT."
        git config -l | egrep '^remote|^svn' | sed 's/^/  /'
        return 1
    fi
    return 0
}
function git_getsrc() {
    #VCSSRC=$(cd $VCS_DIR; git remote get-url origin) ## needs newer git
    #VCSSRC=$(cd $VCS_DIR; git remote -v | grep origin | grep fetch | sed -e "s/origin\s*//" -e "s/\s*(.*)//" ) #" confused mcedit
    VCSSRC=$(cd $VCS_DIR && git config remote.origin.url)
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
