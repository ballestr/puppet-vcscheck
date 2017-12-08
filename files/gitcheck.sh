#!/bin/bash
#####################
# Managed by Puppet #
#####################
# svncheck
# Usage: Check the status of SVN directory
# Author: saqib.haleem
# Version: 1.0  18.8.2010
# Update: 1.1 for /etc/svncheck
# sergio.ballestrero 2011-01-21 
# Update: 1.2 for http upload, /etc/svncheck/*
# sergio.ballestrero 2013-08-09 
# Update: 1.3 for autoupdate and source checks
# sergio.ballestrero 2013-11-03 
# Update: 1.4 for create
# sergio.ballestrero 2013-12-17 
# Update: 1.5 send email if output not interactive else output to screen
# chlee 2014-11-20
# Update: 1.6 single email for updates, with paths
# sergio.ballestrero 2015-01-24
# Update: 2.0 version for Git
# sergio.ballestrero 2017-05

#MY_NAME=`readlink -f  "$0"` # -f fails on OsX
MY_NAME=`readlink "$0"`
SPREAD=1
MAIL_CMD="/usr/sbin/sendmail -t"
USERMAIL=$(mktemp /tmp/svncheck.XXXXXXXXXX)   # mail text
UPDATEMAIL=$(mktemp /tmp/svncheck.XXXXXXXXXX)   # mail text
FROMROOT="<root@$(hostname -f)>"
SYSADMINS="root" # not @localhost, ssmtp does not remap it nicely
REPLYTO=$SYSADMINS
#[ -s /etc/puppet/puppet.conf ] && PUPSRV=$(egrep "^[[:space:]]*server[[:space:]]*=" /etc/puppet/puppet.conf | sed -e "s/.*=\ *//")
export SVN_SSH="ssh -q -o StrictHostKeyChecking=no"

if [ "$1" = "-update" ]; then
   DO_UPDATE=true
   shift
fi

if [ "$1" = "-create" ]; then
   DO_CREATE=true
   shift
fi

if [ $# -eq 0 ]; then
    shopt -s nullglob
    CONFIGS="/etc/vcscheck/git_*.rc"
else
    CONFIGS="$@"
fi

FAIL=0

function check_git() {
    CHECK_LSTATUS=`git status --porcelain` 2>/dev/null
    RL=${PIPESTATUS[0]}
    CHECK_PSTATUS=`git status -v | egrep 'pull|push|ahead|detached'` 2>/dev/null
    #CHECK_PSTATUS=`git status --porcelain -b | egrep 'pull|push|ahead|no branch'` 2>/dev/null ## not yet supperted in SLC6 git 1.7.1
    RP=${PIPESTATUS[0]}
    if [ "$GITINFO" ]; then
        CHECK_FSTATUS=`git fetch --dry-run 2>&1`
	RF=${PIPESTATUS[0]}
    else
	CHECK_FSTATUS=""
    fi
    if [ "$CHECK_LSTATUS" == "" -a "$CHECK_PSTATUS" == "" -a "$CHECK_FSTATUS" == "" ]; then
        echo "## $CONF: $SVN_DIR git status OK, fetch OK, pull OK" >> $USERMAIL
    elif [[ "$CHECK_FSTATUS" =~ "Network connection" ]]; then
        echo -e "## $CONF: network connection failure (s=$CHECK_STATUS):" >> $USERMAIL
        echo $GITINFO | sed -e 's/^/-- /' >> $USERMAIL
        FAIL=1
    else
        echo -e "## $CONF: $SVN_DIR is not in sync or detached (r=$RL/$RP/$RF):" >> $USERMAIL
        echo "--## git status -v :" >> $USERMAIL
        git status -v 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
	if [ "$GITINFO" ]; then
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
        CHECK_SSTATUS=`git submodule status --recursive| grep -v '^ '`
        CHECK_SSTATUS+=`git submodule foreach --recursive "git status|grep detached||true" | grep -B1 detached`
        RS=${PIPESTATUS[0]}
        if [ "$CHECK_SSTATUS" == "" ]; then
            echo "## $CONF: $SVN_DIR git submodule OK" >> $USERMAIL
        else
            echo "## $CONF: $SVN_DIR git submodule status --recursive :" >> $USERMAIL
            git submodule status --recursive 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
            echo "## $CONF: $SVN_DIR git submodule foreach --recursive git status :" >> $USERMAIL
            git submodule foreach --recursive "git status" 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
            FAIL=1
        fi
    fi
}



FAILS=0
for F in $CONFIGS; do
    MAILTO=""
    source $F || continue
    [ "$MAILTO" ] || MAILTO=$SYSADMINS
    CONF=$(basename $F)
    FAIL=0

    ## Actually one single dir, but helps flow control with continue
    for SVN_DIR in $DIR; do

        if [ -z "$SVN_DIR" ] ;  then
            # quietly skip empty
            continue
        fi

        if ! [ -e "$SVN_DIR" -a -e "$SVN_DIR/.git" ]; then
            if [ -n "$DO_CREATE" -a -n "$SOURCE" ]; then
                ## if not empty, move aside
                [ "ls -A $SVN_DIR" ] && mv $SVN_DIR $SVN_DIR.pre_vcscheck
                echo "## $CONF: checkout $SOURCE $SVN_DIR"
                git checkout $SOURCE $SVN_DIR
            fi
        fi
        # must cd to the path, else svn status fails if it is a link
        if ! cd $SVN_DIR/ 2>/dev/null ;  then
            echo "## $CONF: $SVN_DIR is not accessible." >> $USERMAIL
            FAIL=1
            continue
        fi

        if [ -d $SVN_DIR/.git ];  then
            #GITINFO=$(cd $SVN_DIR; git remote get-url origin) ## needs newer git
            GITINFO=$(cd $SVN_DIR; git remote -v | grep origin | grep fetch | sed -e "s/origin\s*//" -e "s/\s*(.*)//" ) #" confused mcedit
            #echo $GITINFO #debug
            [ -e $SVN_DIR/.git/svn ] && SVNINFO=$(cd $SVN_DIR; git svn info)
        else
            echo "## $CONF: $SVN_DIR is not a GIT working directory." >> $USERMAIL
            FAIL=1
            continue
            #SVNINFO=$(cd $SVN_DIR; svn info)
        fi

        if [ -n "$SOURCE" ];  then
            if [ "$GITINFO" != "$SOURCE" ]; then
                #tmp=$(git remote get-url origin) ## needs newer git
                echo "## $CONF: $SVN_DIR source '$GITINFO'">> $USERMAIL
                echo "## $CONF: $SVN_DIR does not match '$SOURCE'." >> $USERMAIL
                FAIL=1 # but do not skip update check anyway
            fi
        fi


        # let's not hammer the server if running from batch...
        [[ -t 0 || -p /dev/stdin || -n "$SSH_CONNECTION" ]] || sleep $[RANDOM%SPREAD]

        CHECK_LSTATUS=`git status --porcelain`

        if [ "$CHECK_LSTATUS" == "" -a  "$AUTOUPDATE" == "true" -a -n "$DO_UPDATE" ]; then
            # TODO: actually handle GIT checkouts (git svn rebase --dry-run not working as expected)
             res=$(git fetch | grep -v "At revision")
             if [ "$res" ]; then
                 ## Check if running interactive, else send output to email
                 if [ -t 0 ]; then 
                     echo "## $CONF: updated $SVN_DIR" >> $UPDATEMAIL
                     echo "$res" >> $UPDATEMAIL
                 else
                     echo "## $CONF: updated $SVN_DIR"
                     echo "$res"
                 fi
             fi
        fi

        check_git
        #continue

    done

    ## post check file to the puppet host
    if [ $FAIL -ne 0 ]; then
        [ "$PUPSRV" ] && curl -sS -F svncheck=@$USERMAIL -Fconf=$CONF http://$PUPSRV/svncheck/submit.php > /dev/null
        if [ -t 0 ] ; then
	       cat $USERMAIL
        else
	        if [ -z "$PUPSRV" ]; then 
    	        ## send mail if no report server defined
                cat $USERMAIL | mail -s "[VCSCHECK] errors on $(hostname -s)" $MAILTO
	        fi
	    fi
    else
        T=$(mktemp /tmp/svncheck.XXXXXXXX) ## Chris: Cant send /dev/null with curl in CC7 ?
        [ "$PUPSRV" ] && curl -sS -F svncheck=@$T -Fconf=$CONF http://$PUPSRV/svncheck/submit.php > /dev/null
        rm $T
    fi
    cat /dev/null > $USERMAIL
    FAILS=$[FAILS+FAIL]
    #shift
done

if [ -s $UPDATEMAIL ] ; then
{
    cat $UPDATEMAIL 
    echo "---"
    echo "Mail sent by $MY_NAME $CONFIGS running on $(hostname)"
}| mail -s "[VCSCHECK] updates on $(hostname -s)"  $MAILTO
fi

rm $USERMAIL $UPDATEMAIL

## exit code, especially for puppet
[ $FAILS -ne 0 ] && exit 1
exit 0
