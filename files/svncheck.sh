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

MY_NAME=`readlink -f  "$0"`
MAIL_CMD="/usr/sbin/sendmail -t"
USERMAIL=$(mktemp /tmp/svncheck.XXXXXXXXXX)   # mail text
UPDATEMAIL=$(mktemp /tmp/svncheck.XXXXXXXXXX)   # mail text
FROMROOT="<root@$(hostname -f)>"
SYSADMINS="root@localhost"
#PUPSRV=$(egrep "^[[:space:]]*server[[:space:]]*=" /etc/puppet/puppet.conf | sed -e "s/.*=\ *//")
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
    CONFIGS="/etc/vcscheck/svn_*.rc"
else
    CONFIGS="$@"
fi

FAILS=0
for F in $CONFIGS; do
    MAILTO=""
    source $F || continue
    [ "$MAILTO" ] || MAILTO=$SYSADMINS
    CONF=$(basename $F)
    FAIL=0

    ## Actually one single dir, but helps flow control with continue
    for SVN_DIR in $DIR; do

        if ! [ -e "$SVN_DIR" -a -e "$SVN_DIR/.svn" ]; then
            if [ -n "$DO_CREATE" -a -n "$SOURCE" ]; then
                ## if not empty, move aside
                [ "ls -A $SVN_DIR" ] && mv $SVN_DIR $SVN_DIR.pre_svncheck
                echo "## $CONF: checkout $SOURCE $SVN_DIR"
                svn checkout $SOURCE $SVN_DIR
            fi
        fi
        # must cd to the path, else svn status fails if it is a link
        if ! cd $SVN_DIR/ 2>/dev/null ;  then
            echo "## $CONF: $SVN_DIR is not accessible." >> $USERMAIL
            FAIL=1
            continue
        fi

        if [ ! -d $SVN_DIR/.svn ];  then
            echo "## $CONF: $SVN_DIR is not an SVN working directory." >> $USERMAIL
            FAIL=1
            continue
        fi

        # TODO: actually handle GIT checkouts (git svn rebase --dry-run not working as expected)
        if [ -d $SVN_DIR/.git ];  then
            SVNINFO=$(cd $SVN_DIR; git svn info)
            continue
        else
            SVNINFO=$(cd $SVN_DIR; svn info)
        fi

        if [ -z "$SVN_DIR" ] ;  then
            # quietly skip empty
            continue
        fi

        if [ -n "$SOURCE" ];  then
            if ! echo -e "$SVNINFO" | grep -q "$SOURCE" ; then
  				tmp=$(head .svn/entries | egrep "^svn.*:" | head -1)
                echo "## $CONF: $SVN_DIR source '$tmp'">> $USERMAIL
                echo "## $CONF: $SVN_DIR does not match '$SOURCE'." >> $USERMAIL
                FAIL=1 # but do not skip update check anyway
            fi
        fi

        # let's not hammer the server if running from batch...
        [[ -t 0 || -p /dev/stdin || -n "$SSH_CONNECTION" ]] || sleep $[RANDOM%150]
        if [ "$AUTOUPDATE" = "true" -a -n "$DO_UPDATE" ]; then
             res=$(svn update | grep -v "At revision")
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
        CHECK_STATUS=`svn status -u 2>&1 | sed -e '/^Status/ d'` 2>/dev/null
        R=${PIPESTATUS[0]}
        if [ "$CHECK_STATUS" == "" ]; then
            echo "## $CONF: $SVN_DIR status -u ok" >> $USERMAIL
        elif [[ "$CHECK_STATUS" =~ "Network connection" ]]; then
            echo -e "## $CONF: network connection failure (s=$CHECK_STATUS):" >> $USERMAIL
            svn info | grep "^Repository Root:" | sed -e 's/^/-- /' >> $USERMAIL
            FAIL=1
        else
            echo -e "## $CONF: $SVN_DIR is not in sync (r=$R):" >> $USERMAIL
            svn status -u 2>&1 | sed -e 's/^/-- /' >> $USERMAIL
            FAIL=1
        fi
    done

    ## post check file to the puppet host
    if [ $FAIL -ne 0 ]; then
        [ "$PUPSRV" ] && curl -sS -F svncheck=@$USERMAIL -Fconf=$CONF http://$PUPSRV/svncheck/submit.php > /dev/null
        if [ -t 0 ] ; then
	    cat $USERMAIL
        else
	    if [ -z "$PUPSRV" ]; then 
	    ## send mail if no report server defined
    	    cat $USERMAIL | mail -s "[SVNCHECK] errors on $(hostname -s)" $MAILTO
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
}| mail -s "[SVNCHECK] updates on $(hostname -s)"  $MAILTO
fi

rm $USERMAIL $UPDATEMAIL

## exit code, especially for puppet
[ $FAILS -ne 0 ] && exit 1
