class vcscheck::base {
    file {"/etc/vcscheck":ensure=>directory}
    file {"/etc/cron.daily/vcsfind":source=>"puppet:///modules/vcscheck/vcsfind.sh"}
}
