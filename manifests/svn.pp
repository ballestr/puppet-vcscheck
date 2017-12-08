define vcscheck::svn ($path,$source=undef,$autoupdate=false) {
    include vcscheck::svn::base
    $MAILTO=hiera("mail_sysadmins","root")
    file {"/etc/vcscheck/svn_${name}.rc": content=>"MAILTO=$MAILTO\nDIR=$path\nSOURCE=$source\n"}
}

class vcscheck::svn::base {
    include vcscheck::base
    package {"subversion":ensure=>present}
    file {"/etc/cron.hourly/svncheck":source=>"puppet:///modules/vcscheck/svncheck.sh"}
    file {"/usr/local/bin/svncheck":source=>"puppet:///modules/vcscheck/svncheck.sh"}
    file {"/etc/cron.daily/svncheck.sh":ensure=>absent}
    file {"/usr/local/bin/svncheck.sh":ensure=>absent}
}
