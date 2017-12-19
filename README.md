# puppet-vcscheck
Version Control System directory status checks

Check if a Git clone or Subversion checkout are in consistent and updated status, sending notifications.
Create or pull/update if desired.

Note that the "official" module vcsrepo (https://forge.puppet.com/puppetlabs/vcsrepo) 
is only intended for puppet 

## Example
```
vcscheck::svn{"sysadm":
  path=>"/root/sysadm",
  autoupdate=>true,
  create=>true,
  source=>"svn+ssh://somewhere.net/data/svn/sysadm"
}
vcscheck::git{"puppet":
  path=>"/etc/puppet",
  source=>"https://somewhere.net/data/git/sysadm_puppet_home.git"
}
```

## Notifications and reporting
Notifications are sent by e-mail - `hiera("mail_sysadmins","root")` .

Consolidated reporting had been implemented for ATLAS TDAQ (Online farm), will be resurrected here too.

In the future, the vcscheck scripts will also support being used as Nagios/Icinga service checks.


## Manual usage
The module deploys `/usr/local/bin/vcscheck`,  which can also be used manually.
```
vcscheck [--update] [--create] [--nagios] [configfile]
```
If no configfile is specified, all those present in `/etc/vcscheck` will be used.

Also `/usr/local/bin/vcsfind` is available, funcionality is minimal.

Note: for manual use for git, you may want to check also https://github.com/badele/gitcheck

## To Do
- [x] Merge GIT and SVN in a single `vcscheck` script
- [ ] Support `git svn` repo clones
- [x] Support Nagios checks
- [ ] Extend `vcsfind` 
- [ ] Consolidated reporting
