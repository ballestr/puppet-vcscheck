define vcscheck::git ($path,$source=undef) {
    include vcscheck::git::base
    $MAILTO=hiera("mail_sysadmins","root@localhost")
    file {"/etc/vcscheck/git_${name}.rc": content=>"MAILTO=$MAILTO\nDIR=$path\nSOURCE=$source\n"}
}

class vcscheck::git::base {
    include vcscheck::base
    package {"git":ensure=>present}
    file {"/etc/cron.daily/gitcheck.sh":source=>"puppet:///modules/vcscheck/gitcheck.sh"}
    file {"/usr/local/bin/gitcheck.sh":source=>"puppet:///modules/vcscheck/gitcheck.sh"}
}
