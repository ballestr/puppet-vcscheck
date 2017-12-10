define vcscheck::git ($path,$source=undef,$create=false,$autoupdate=false) {
    include vcscheck::git::base
    vcscheck::cfg{ $name: type=>'git',dir=>$path,source=>$source,create=>$create,autoupdate=>$autoupdate }
}

class vcscheck::git::base {
    include vcscheck::base
    package {"git":ensure=>present}

    ## cleanup old versions
    file {["/etc/cron.daily/gitcheck.sh","/etc/cron.hourly/gitcheck"]:ensure=>absent}
    file {["/usr/local/bin/gitcheck.sh","/usr/local/bin/gitcheck"]:ensure=>absent}

}
