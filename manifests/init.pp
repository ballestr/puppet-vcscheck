class vcscheck::base {
    file {"/usr/local/bin/vcslib.sh":source=>"puppet:///modules/vcscheck/vcslib.sh"}
    file {"/usr/local/bin/vcsnotify":ensure=>absent}
    file {"/etc/vcscheck":ensure=>directory}
    tidy {
        "/etc/vcscheck":
            age => 0, recurse => true, matches => "*", require => File["/etc/vcscheck"]
    }

    $script="/usr/local/bin/vcscheck"
    file {$script:source=>"puppet:///modules/vcscheck/vcscheck"}

    ## deploy cronjob
    $MAILTO=hiera("mail_sysadmins","root")
    $r=13+fqdn_rand(15)
    crond::job {
        "vcscheck_all":
        mail=>$MAILTO,
        comment=>"run vcscheck on all",
        jobs=>[
            #"$r 00-08 * * * root nice $script",
            "$r    09 * * * root nice $script -update",
            "$r 10-20 * * * root nice $script"
        ],
        require=>File[$script];
    }
}

define vcscheck::cfg ($type,$dir,$source,$create,$autoupdate) {
    $MAILTO=hiera("mail_sysadmins","root")
    file {"/etc/vcscheck/${type}_${name}.rc": 
    content=>"## Managed by Puppet ##\n# vcscheck::cfg ${name} ${type}\nMAILTO=$MAILTO\nTYPE=$type\nDIR=$dir\nSOURCE=$source\nCREATE=$create\nAUTOUPDATE=$autoupdate\n"}
}

## a daily cronjob to search and report on VCS directories 
## which are not declared & managed by vcscheck
class vcscheck::find {
    include vcscheck::base
    file {"/etc/cron.daily/vcsfind":source=>"puppet:///modules/vcscheck/vcsfind"}
}


## define (virtual) packages
## include it if you do not have them defined elsewhere
class vcscheck::package {
    @package {"subversion":ensure=>present}
    @package {"git":ensure=>present}
}
