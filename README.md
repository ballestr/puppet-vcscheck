# puppet-vcscheck
Version Control System checks

Check if a Git clone or Subversion checkout are in good status, sending notifications
Create or update if desired.

Note that the "official" module vcsrepo (https://forge.puppet.com/puppetlabs/vcsrepo) 
is only intended for puppet 

## Example
```
vcscheck::svn{"sysadm":
  path=>"/root/sysadm",
  autoupdate=>true,
  create=>true,
  source=>"file:///data/svn/sysadm"
}
vcscheck::git{"puppet":
  path=>"/etc/puppet",
  source=>"/data/git/sysadm_puppet_home.git"
}
```

## Notifications and reporting
Notifications are sent by e-mail - `hiera("mail_sysadmins","root")` .

Consolidated reporting had been implemented for ATLAS TDAQ (Online farm), will be resurrected here too.

In the future, the vcscheck scripts will also support being used as Nagios/Icinga service checks.


## Manual usage
The module deploys `/usr/local/bin/svncheck` or `/usr/local/bin/gitcheck` which can also be used manually.
```
gitcheck [-update] [-create] [configfile]
```
If no configfile is specified, all those present in `/etc/vcscheck` will be used.

Also `/usr/local/bin/vcsfind` is available, funcionality is minimal.

## To Do
[ ] Merge GIT and SVN in a single `vcscheck` script
[ ] Support `git svn` repo clones
[ ] Support Nagios checks
[ ] Extend `vcsfind` 
[ ] Consolidated reporting
