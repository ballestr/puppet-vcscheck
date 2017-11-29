define vcscheck::svn ($path,$source=undef) {
    include vcscheck::svn::base
    $MAILTO=hiera("mail_sysadmins","root@localhost")
    file {"/etc/vcscheck/svn_${name}.rc": content=>"MAILTO=$MAILTO\nDIR=$path\nSOURCE=$source\n"}
}

class vcscheck::svn::base {
    include vcscheck::base
    package {"subversion":ensure=>present}
    file {"/etc/cron.daily/svncheck.sh":source=>"puppet:///modules/vcscheck/svncheck.sh"}
    file {"/usr/local/bin/svncheck.sh":source=>"puppet:///modules/vcscheck/svncheck.sh"}
}
