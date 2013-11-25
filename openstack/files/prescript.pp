if $::operatingsystem == 'CentOS' {
    package{ 'selinux-policy':
        ensure => latest,
    }
}
elsif $::operatingsystem != "Fedora" {
    package{ 'openstack-selinux':
        ensure => present,
    }
}

if $::operatingsystem == 'RedHat' {
    $warning = "Kernel package with netns support has been installed on host $::ipaddress. Please note that with this action you are losing Red Hat support for this host. Because of the kernel update the host mentioned above requires reboot."
} else {
    $warning = "Kernel package with netns support has been installed on host $::ipaddress. Because of the kernel update the host mentioned above requires reboot."
}

class { 'packstack::netns':
    warning => $warning
}
