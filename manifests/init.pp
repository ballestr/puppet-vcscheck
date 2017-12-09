class vcscheck::base {
    file {"/etc/cron.daily/vcsfind":source=>"puppet:///modules/vcscheck/vcsfind"}
    file {"/usr/local/bin/vcsnotify":source=>"puppet:///modules/vcscheck/vcsnotify"}
    file {"/etc/vcscheck":ensure=>directory}
    tidy {
        "/etc/vcscheck":
            age => 0, recurse => true, matches => "*", require => File["/etc/vcscheck"]
    }
}

define vcscheck::cfg ($type,$dir,$source,$create,$autoupdate) {
    $MAILTO=hiera("mail_sysadmins","root")
    file {"/etc/vcscheck/${type}_${name}.rc": 
    content=>"## Managed by Puppet ##\n# vcscheck::cfg ${name} ${type}\nMAILTO=$MAILTO\nDIR=$dir\nSOURCE=$source\nCREATE=$create\nAUTOUPDATE=$autoupdate\n"}
}
