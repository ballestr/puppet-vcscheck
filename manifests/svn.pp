define vcscheck::svn ($path,$source=undef,$create=false,$autoupdate=false) {
    include vcscheck::svn::base
    vcscheck::cfg{ $name: type=>'svn',dir=>$path,source=>$source,create=>$create,autoupdate=>$autoupdate }
}

class vcscheck::svn::base {
    include vcscheck::base
    package {"subversion":ensure=>present}

    file {"/etc/cron.hourly/svncheck":ensure=>absent}
    file {"/usr/local/bin/svncheck":ensure=>absent}
    ## cleanup old versions
    file {"/etc/cron.daily/svncheck.sh":ensure=>absent}
    file {"/usr/local/bin/svncheck.sh":ensure=>absent}
}
