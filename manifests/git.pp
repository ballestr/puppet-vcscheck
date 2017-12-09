define vcscheck::git ($path,$source=undef,$create=false,$autoupdate=false) {
    include vcscheck::git::base
    vcscheck::cfg{ $name: type=>'git',dir=>$path,source=>$source,create=>$create,autoupdate=>$autoupdate }
}

class vcscheck::git::base {
    include vcscheck::base
    package {"git":ensure=>present}
    file {"/etc/cron.hourly/gitcheck":source=>"puppet:///modules/vcscheck/gitcheck.sh"}
    file {"/usr/local/bin/gitcheck":source=>"puppet:///modules/vcscheck/gitcheck.sh"}
    ## cleanup old versions
    file {"/etc/cron.daily/gitcheck.sh":ensure=>absent}
    file {"/usr/local/bin/gitcheck.sh":ensure=>absent}

# nice cronjobs
#27 00-08 * * * root nice /usr/local/sbin/svncheck
#27    09 * * * root nice /usr/local/sbin/svncheck -update
#27 10-23 * * * root nice /usr/local/sbin/svncheck

}
