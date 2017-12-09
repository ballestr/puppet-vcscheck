
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
