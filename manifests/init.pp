class vcscheck::base {
    file {"/etc/vcscheck":ensure=>directory}
    file {"/etc/cron.daily/vcsfind":source=>"puppet:///modules/vcscheck/vcsfind"}
    file {"/usr/local/bin/vcsnotify":source=>"puppet:///modules/vcscheck/vcsnotify"}
}

define vcscheck::cfg ($type) {
    $MAILTO=hiera("mail_sysadmins","root")
	file {"/etc/vcscheck/${type}_${name}.rc": 
    content=>"## Managed by Puppet ##\# vcscheck::cfg ${name} ${type}\nMAILTO=$MAILTO\nDIR=$path\nSOURCE=$source\nCREATE=$create\nAUTOUPDATE=$autoupdate\n"}
}