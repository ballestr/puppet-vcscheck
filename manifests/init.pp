## base installation of scripts and cronjob
class vcscheck::base {
    file {'/usr/local/bin/vcslib.sh':source=>'puppet:///modules/vcscheck/vcslib.sh'}
    file {'/usr/local/bin/vcsnotify':ensure=>absent}
    file {'/etc/vcscheck':ensure=>directory}
    tidy {
        '/etc/vcscheck':
            recurse => true, matches => "*", require => File['/etc/vcscheck']
    }

    $script='/usr/local/bin/vcscheck'
    file {$script:source=>'puppet:///modules/vcscheck/vcscheck'}

    ## deploy cronjob
    $mailto=hiera("vcscheck/mailto","root")
    $r=13+fqdn_rand(15)
    crond::job {
        "vcscheck_all":
        mail    =>$mailto,
        comment =>"run vcscheck on all",
        jobs    =>[
            #"${r} 00-08 * * * root nice ${script}",
            #"${r}    09 * * * root nice ${script} --update",
            "${r} 09-20 * * * root nice ${script} --update"
        ],
        require =>File[$script];
    }
}

## write the configuration file
define vcscheck::cfg ($type,$dir,$source,$create,$autoupdate) {
    $mailto=hiera('vcscheck/mailto','root')
    $notify_url=hiera('vcscheck/notify_url',"")
    $notify_secret=hiera('vcscheck/notify_secret',"")
    file {"/etc/vcscheck/${type}_${name}.rc":
    content=>"## Managed by Puppet ##\n# vcscheck::cfg ${name} ${type}\nMAILTO=${mailto}\nNOTIFYURL=${notify_url}\nNOTIFYSECRET=${notify_secret}\nTYPE=${type}\nDIR=${dir}\nSOURCE=${source}\nCREATE=${create}\nAUTOUPDATE=${autoupdate}\n"}
    if $create==true {
        ## use the vcscheck script to checkout
        exec {
            "vcscheck_${name}_create":
                command =>"/usr/local/bin/vcscheck -create ${cfgfile}",
                unless  => "/usr/bin/test -d $dir/.$type",
                require =>File["/etc/vcscheck/${type}_${name}.rc"];
        }
    }
}

## a daily cronjob to search and report on VCS directories 
## which are not declared & managed by vcscheck
class vcscheck::find($period="weekly") {
    include vcscheck::base
    file {"/etc/cron.${period}/vcsfind":source=>"puppet:///modules/vcscheck/vcsfind"}
}


## define (virtual) packages
## include it if you do not have them defined elsewhere
class vcscheck::package {
    @package {'subversion':ensure=>present}
    @package {'git':ensure=>present}
}
