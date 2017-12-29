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
Notifications are sent by e-mail - `hiera("vcscheck/mailto","root")` .

Consolidated reporting had been implemented for ATLAS TDAQ (Online farm), will be resurrected here too.

In the future, the vcscheck scripts will also support being used as Nagios/Icinga service checks.


## Manual usage
The module deploys `/usr/local/bin/vcscheck`,  which can also be used manually.
```
vcscheck [--update] [--create] [--nagios] [configfiles|directories]
```
If no configfile is specified, all those present in `/etc/vcscheck/*.rc` and `$HOME/.config/vcscheck/*.rc` will be used.

If a directory is specified, no config file will be read (will not search for a correspnding config).

Also `/usr/local/bin/vcsfind` is available, funcionality is minimal.

Note: for manual use for git, you may want to check also https://github.com/badele/gitcheck

## To Do
- [x] fix updates for Git
- [x] resurrect reporting API
- [x] Merge GIT and SVN in a single `vcscheck` script
- [x] config files also in `$HOME/.config/vcscheck/*.rc`
- [x] check directory without config, like `vcscheck .` or `vcscheck *` (Git only)
- [x] Detailed config check on git svn
- [ ] check for correct git branch or tag
- [ ] check for non-current, non-pushed branches (avoid forgetting/losing local work)
- [ ] Support `git svn` repo clones
- [x] Support Nagios checks
- [ ] Extend `vcsfind` 
- [ ] Consolidated reporting
