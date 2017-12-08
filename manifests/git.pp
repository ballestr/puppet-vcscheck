define vcscheck::git ($path,$source=undef,$create=undef) {
    include vcscheck::git::base
    $MAILTO=hiera("mail_sysadmins","root")
    file {"/etc/vcscheck/git_${name}.rc": content=>"MAILTO=$MAILTO\nDIR=$path\nSOURCE=$source\n"}
}

class vcscheck::git::base {
    include vcscheck::base
    package {"git":ensure=>present}
    file {"/etc/cron.hourly/gitcheck":source=>"puppet:///modules/vcscheck/gitcheck.sh"}
    file {"/usr/local/bin/gitcheck":source=>"puppet:///modules/vcscheck/gitcheck.sh"}
    ## cleanup old versions
    file {"/etc/cron.daily/gitcheck.sh":ensure=>absent}
    file {"/usr/local/bin/gitcheck.sh":ensure=>absent}
}
