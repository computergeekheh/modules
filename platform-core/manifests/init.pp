#
#
#
class platform-core {

   package { [ 'bind-utils', 'openssh-clients', 'openssh-server', 'vim-enhanced', 'sysstat', 'telnet', 'man', 'sudo', 'screen' ]: ensure  => latest; }

#    include extensions
#    include yum
#    include authkeys
    include network
#    include xinetd
#    include resolv_conf
#    include puppetd
#    include puppet-client
    include disk-config
#    include ntp

}
