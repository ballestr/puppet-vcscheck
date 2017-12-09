define vcscheck::svn ($path,$source=undef,$create=false,$autoupdate=false) {
    include vcscheck::svn::base
    vcscheck::cfg{ $name: type=>'svn' }
}

class vcscheck::svn::base {
    include vcscheck::base
    package {"subversion":ensure=>present}
    file {"/etc/cron.hourly/svncheck":source=>"puppet:///modules/vcscheck/svncheck"}
    file {"/usr/local/bin/svncheck":source=>"puppet:///modules/vcscheck/svncheck"}
    ## cleanup old versions
    file {"/etc/cron.daily/svncheck.sh":ensure=>absent}
    file {"/usr/local/bin/svncheck.sh":ensure=>absent}
}
