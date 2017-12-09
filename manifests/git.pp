define vcscheck::git ($path,$source=undef,$create=false,$autoupdate=false) {
    include vcscheck::git::base
    vcscheck::cfg{ $name: type=>'git',dir=>$path,source=>$source,create=>$create,autoupdate=>$autoupdate }
}

class vcscheck::git::base {
    include vcscheck::base
    $script="/usr/local/bin/gitcheck"
    package {"git":ensure=>present}
    #file {"/etc/cron.hourly/gitcheck":source=>"puppet:///modules/vcscheck/gitcheck"}
    file {$script:source=>"puppet:///modules/vcscheck/gitcheck"}

    ## cleanup old versions
    file {["/etc/cron.daily/gitcheck.sh","/etc/cron.hourly/gitcheck"]:ensure=>absent}
    file {["/usr/local/bin/gitcheck.sh"]:ensure=>absent}

    $MAILTO=hiera("mail_sysadmins","root")
    $r=13+fqdn_rand(15)
    crond::job {
        "gitcheck_all":
        mail=>$MAILTO,
        comment=>"run gitcheck on all",
        jobs=>[
            #"$r 00-08 * * * root nice $script",
            "$r    09 * * * root nice $script -update",
            "$r 10-20 * * * root nice $script"
        ],
        require=>File[$script];
    }
}
