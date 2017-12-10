#!/bin/bash
## Managed by Puppet ##
# Function library for vcscheck
# From https://github.com/ballestr/puppet-vcscheck

## push status to a central collector
function vcsnotify() {
    local CONF=$1
    local USERMAIL=$2
    local VCSSRV

    ## post check file to the puppet host
    [ -s /etc/puppet/puppet.conf ] && VCSSRV=$(egrep "^[[:space:]]*server[[:space:]]*=" /etc/puppet/puppet.conf | sed -e "s/.*=\ *//")

    if [ "$2" = "OK" ]; then
        T=$(mktemp /tmp/vcscheck.XXXXXXXX) ## Chris: Cant send /dev/null with curl in CC7 ?
        [ "$VCSSRV" ] && curl -sS -F svncheck=@$T -Fconf=$CONF http://$VCSSRV/svncheck/submit.php > /dev/null
        rm $T
    else
        [ "$VCSSRV" ] && curl -sS -F svncheck=@$USERMAIL -Fconf=$CONF http://$VCSSRV/svncheck/submit.php > /dev/null
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
    local CHECK_PSTATUS=`git status -v | egrep 'pull|push|ahead|detached'` 2>/dev/null
    #CHECK_PSTATUS=`git status --porcelain -b | egrep 'pull|push|ahead|no branch'` 2>/dev/null ## not yet supperted in SLC6 git 1.7.1
    local RP=${PIPESTATUS[0]}
    if [ "$VCSSRC" ]; then
        local CHECK_FSTATUS=`git fetch --dry-run 2>&1`
        local RF=${PIPESTATUS[0]}
    else
        local CHECK_FSTATUS=""
    fi
    if [ "$CHECK_LSTATUS" == "" -a "$CHECK_PSTATUS" == "" -a "$CHECK_FSTATUS" == "" ]; then
        echo "## $CONF: $VCS_DIR git status OK, fetch OK, pull OK" >> $USERMAIL
    elif [[ "$CHECK_FSTATUS" =~ "Network connection" ]]; then
        echo -e "## $CONF: network connection failure (s=$CHECK_STATUS):" >> $USERMAIL
        echo $VCSSRC | sed -e 's/^/-- /' >> $USERMAIL
        FAIL=1
    else
        echo -e "## $CONF: $VCS_DIR is not in sync or detached (r=$RL/$RP/$RF):" >> $USERMAIL
        echo "--## git status -v :" >> $USERMAIL
        git status -v 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
        if [ "$VCSSRC" ]; then
            echo "--## git fetch dry-run :" >> $USERMAIL
            git fetch --dry-run 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
        else
            echo "--## local repo, no check on git fetch" >> $USERMAIL
        fi
        echo "--## git show -s :" >> $USERMAIL
        git show -s 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
        FAIL=1
    fi
    if [ -f .gitmodules ]; then
        local CHECK_SSTATUS
        CHECK_SSTATUS=`git submodule status --recursive| grep -v '^ '`
        CHECK_SSTATUS+=`git submodule foreach --recursive "git status|grep detached||true" | grep -B1 detached`
        RS=${PIPESTATUS[0]}
        if [ "$CHECK_SSTATUS" == "" ]; then
            echo "## $CONF: $VCS_DIR git submodule OK" >> $USERMAIL
        else
            echo "## $CONF: $VCS_DIR git submodule status --recursive :" >> $USERMAIL
            git submodule status --recursive 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
            echo "## $CONF: $VCS_DIR git submodule foreach --recursive git status :" >> $USERMAIL
            git submodule foreach --recursive "git status" 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
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
        echo "## $CONF: $VCS_DIR is not a GIT working directory." >> $USERMAIL
        return 1
    fi
    if [ -e $VCS_DIR/.git/svn ]; then
        echo "## $CONF: $VCS_DIR is a GIT SVN working directory, not pure GIT." >> $USERMAIL
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
    CHECK_STATUS=`svn status -u 2>&1 | sed -e '/^Status/ d'` 2>/dev/null
    R=${PIPESTATUS[0]}
    if [ "$CHECK_STATUS" == "" ]; then
        echo "## $CONF: $VCS_DIR status -u ok" >> $USERMAIL
    elif [[ "$CHECK_STATUS" =~ "Network connection" ]]; then
        echo -e "## $CONF: network connection failure (s=$CHECK_STATUS):" >> $USERMAIL
        svn info | grep "^Repository Root:" | sed -e 's/^/-- /' >> $USERMAIL
        FAIL=1
    else
        echo -e "## $CONF: $VCS_DIR is not in sync (r=$R):" >> $USERMAIL
        svn status -u 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
        FAIL=1
    fi
}

function svn_update() {
    res=$(svn update | grep -v "At revision")
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
        echo "## $CONF: $VCS_DIR is not an SVN working directory." >> $USERMAIL
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
        echo "## $CONF: $VCS_DIR is a GIT SVN working directory" >> $USERMAIL
        VCSSRC=$(cd $VCS_DIR; git svn info)
    fi
}

function gitsvn_update() {
    # TODO: actually handle GIT checkouts (git svn rebase --dry-run not working as expected)
    true
}
