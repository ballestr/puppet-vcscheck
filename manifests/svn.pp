## set autoupdate=false to disable
define vcscheck::svn ($path,$source=undef,$create=true,$autoupdate=true) {
    include vcscheck::svn::base
    vcscheck::cfg{ $name: type=>'svn',dir=>$path,source=>$source,create=>$create,autoupdate=>$autoupdate }
}

class vcscheck::svn::base {
    include vcscheck::base
    realize Package["subversion"]

    ## cleanup old versions
    file {"/etc/cron.hourly/svncheck":ensure=>absent}
    file {"/usr/local/bin/svncheck":ensure=>absent}
    file {"/etc/cron.daily/svncheck.sh":ensure=>absent}
    file {"/usr/local/bin/svncheck.sh":ensure=>absent}
}
