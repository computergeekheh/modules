#
class openstack {

}

define openstack_install ( $horizon="none", $keystone="none", $quantum="none", $swift="none", $glance="none", $install_mode="none", $dependancy="") {

    $ip_int = "ipaddress_$openstack_private_interface"  # if more than one network.. most often used.
    $ip = (inline_template("<%= scope[@ip_int] %>"))

    if $openstack_private_interface {			# if this hasn't been set, simply do recipe
      if $ip {						# with $openstack_private_interface done let's make sure the network is complete

	case $cephfs {

	  yes: {

	    package { "kernel-uek-3.8.13-16.2.1.el6uek": ensure  => present; }

            file { "/boot/grub/grub.conf":
                owner       => "root",
                group       => "root",
                mode        => 0600,
		content     => template( "openstack/grub.erb" ),
                require     => [Exec["packstack-install"], Package["kernel-uek-3.8.13-16.2.1.el6uek"]];
            }
            exec { "kernel-reboot":
                command     => "/sbin/reboot ",
                unless      => "/bin/uname -r | /bin/grep 3.8.13-16.2.1.el6uek.x86_64 ",
		onlyif	    => "/sbin/chkconfig --list | /bin/grep openstack && /usr/bin/facter | /bin/grep 'gateway =>'",
		before      => Package["ceph"],
                require     => File["/boot/grub/grub.conf"];
            }
	   }
	}

        case $ceph_cluster {

          yes: { package { "ceph": ensure  => latest; }

            file { "/root/.bashrc":
                owner   => "root",
                group   => "root",
                mode    => 0644,
                content => template( "openstack/bashrc.erb" ),
                require => Package["ceph"];
            }
	  }
	}

        case $ceph_rdo {

          yes: {

            exec { "rdo admin prep":
                command     => "/usr/bin/ssh $primary 'ceph-deploy admin $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $primary 'ceph -s' | /bin/grep cluster ",
                require     => [Package["ceph"], Exec["packstack-install"]];
            }
            exec { "rdo keys prep":
                command     => "/usr/bin/ssh $primary 'ceph-deploy gatherkeys $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $primary 'ceph -s' | /bin/grep cluster ",
                require     => Exec["rdo admin prep"];
            }
            file { "/etc/cinder/cinder.conf":
                mode    => 0644,
		notify  => Service["openstack-cinder-volume"],
                content => template( "openstack/cinder.erb" ),
                require => Exec["rdo keys prep"];
            }
            file { "/etc/nova/nova.conf":
                mode    => 0644,
                notify  => Service["openstack-nova-compute"],
                content => template( "openstack/nova.erb" ),
                require => File["/etc/cinder/cinder.conf"];
            }
            file { "/etc/sysconfig/openstack-cinder-volume":
                mode    => 0644,
                notify  => Service["openstack-cinder-volume"],
                content => template( "openstack/openstack-cinder-volume.erb" ),
                require => File["/etc/nova/nova.conf"];
            }

        service { "openstack-nova-compute":    ensure => running, require => Exec["packstack-install"]; }
        service { "openstack-cinder-scheduler":    ensure => running, require => Exec["packstack-install"]; }
        service { "openstack-cinder-volume": ensure => running, require => Exec["packstack-install"]; }
        service { "openstack-cinder-api":      ensure => running, require => Exec["packstack-install"]; }

	  }
	}

        package { "openstack-packstack": ensure  => latest; }

	case $install_mode {

	  all-in-one: {
            file { "/tmp/packstack-answers.$fqdn":
                owner	=> "root",
                group	=> "root",
		mode	=> 0644,
                content => template( "openstack/packstack-answers_all_in_one.erb" ),
                require => Package["openstack-packstack"];
            }
            file { "/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp":
                source  => "puppet://puppet/modules/openstack/prescript.pp",
                require => File["/tmp/packstack-answers.$fqdn"];
            }
	    exec { "packstack-install":
		environment => [ "HOME=/root"],
		command     => "/usr/bin/packstack --answer-file=/tmp/packstack-answers.$fqdn ",
		timeout     => 7200,
		unless 	    => "/sbin/chkconfig --list | /bin/grep openstack",
                onlyif      => "/usr/bin/facter | /bin/grep 'gateway =>'",
		require     => File["/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp"];
	    }
            exec { "set mysql for add on":
                command     => "/usr/bin/mysql --user=root --password=$password -NBe \"grant ALL on *.* to 'root'@'%' identified by '$password'\"",
                onlyif      => "/bin/grep export /root/.bashrc",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["packstack-install"];
            }
            exec { "flush privilages": 
                command     => "/usr/bin/mysql --user=root --password=$password -NBe  \"flush privileges\"",
                onlyif      => "/bin/grep export /root/.bashrc",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["set mysql for add on"];
            }
	  }
	  nova_compute: {
		
            package { "mysql": ensure  => latest; }

            file { "/tmp/packstack-answers.$fqdn":
                mode    => 0644,
	   	replace => false,
                content => template( "openstack/packstack-answers_nova_compute.erb" ),
                require => Package["openstack-packstack"];
            }
            exec { "node specific answer change":
                command     => "/bin/bash -c \"sed -i 's/$dashboard/`host $dashboard | awk '{print \$4}'`/g' /tmp/packstack-answers.$fqdn \" ",
                onlyif      => "/bin/grep $dashboard /tmp/packstack-answers.$fqdn",
                require     => File["/tmp/packstack-answers.$fqdn"];
            }
            file { "/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp":
 		source  => "puppet://puppet/modules/openstack/prescript.pp",
                require => Exec["node specific answer change"];
            }
            exec { "packstack-install":
                environment => [ "HOME=/root"],
                command     => "/usr/bin/packstack --answer-file=/tmp/packstack-answers.$fqdn ",
                timeout     => 7200,
                unless      => "/sbin/chkconfig --list | /bin/grep openstack",
                onlyif      => "/usr/bin/facter | /bin/grep 'gateway =>'",
                require     => File["/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp"];
            }
	  }
	}
     } else { notify {'Networking needs to be done first, delaying OpenStack install':} } # Templat will fail if refferenced eth1 and it doen't exist

   } else {

        case $cephfs {

          yes: {

            package { "kernel-uek-3.8.13-16.2.1.el6uek": ensure  => present; }

            file { "/boot/grub/grub.conf":
                owner       => "root",
                group       => "root",
                mode        => 0600,
                content     => template( "openstack/grub.erb" ),
                require     => [Exec["packstack-install"], Package["kernel-uek-3.8.13-16.2.1.el6uek"]];
            }
            exec { "kernel-reboot":
                command     => "/sbin/reboot ",
                unless      => "/bin/uname -r | /bin/grep 3.8.13-16.2.1.el6uek.x86_64 ",
                onlyif      => "/sbin/chkconfig --list | /bin/grep openstack && /usr/bin/facter | /bin/grep 'gateway =>'",
                before      => Package["ceph"],
                require     => File["/boot/grub/grub.conf"];
            }
           }
        }

        case $ceph_cluster {

          yes: { package { "ceph": ensure  => latest; }

            file { "/root/.bashrc":
                owner   => "root",
                group   => "root",
                mode    => 0644,
                content => template( "openstack/bashrc.erb" ),
                require => Package["ceph"];
            }
          }
        }

        case $ceph_rdo {

          yes: {

            exec { "rdo admin prep":
                command     => "/usr/bin/ssh $primary 'ceph-deploy admin $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $primary 'ceph -s' | /bin/grep cluster ",
                require     => [Package["ceph"], Exec["packstack-install"]];
            }
            exec { "rdo keys prep":
                command     => "/usr/bin/ssh $primary 'ceph-deploy gatherkeys $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $primary 'ceph -s' | /bin/grep cluster ",
                require     => Exec["rdo admin prep"];
            }
            file { "/etc/cinder/cinder.conf":
                mode    => 0644,
                notify  => Service["openstack-cinder-volume"],
                content => template( "openstack/cinder.erb" ),
                require => Exec["rdo keys prep"];
            }
            file { "/etc/nova/nova.conf":
                mode    => 0644,
                notify  => Service["openstack-nova-api"],
                content => template( "openstack/nova.erb" ),
                require => File["/etc/cinder/cinder.conf"];
            }
            file { "/etc/sysconfig/openstack-cinder-volume":
                mode    => 0644,
                notify  => Service["openstack-glance-api"],
                content => template( "openstack/openstack-cinder-volume.erb" ),
                require => File["/etc/nova/nova.conf"];
            }

        service { "openstack-cinder-volume": ensure => running; }
        service { "openstack-nova-api":      ensure => running; }
        service { "openstack-glance-api":    ensure => running; }

          }
        }

        package { "openstack-packstack": ensure  => latest; }

        case $install_mode {

          all-in-one: {
            file { "/tmp/packstack-answers.$fqdn":
                owner   => "root",
                group   => "root",
                mode    => 0644,
                content => template( "openstack/packstack-answers_all_in_one.erb" ),
                require => Package["openstack-packstack"];
            }
            file { "/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp":
                source  => "puppet://puppet/modules/openstack/prescript.pp",
                require => File["/tmp/packstack-answers.$fqdn"];
            }
            exec { "packstack-install":
                environment => [ "HOME=/root"],
                command     => "/usr/bin/packstack --answer-file=/tmp/packstack-answers.$fqdn ",
                timeout     => 7200,
                unless      => "/sbin/chkconfig --list | /bin/grep openstack",
                onlyif      => "/usr/bin/facter | /bin/grep 'gateway =>'",
                require     => File["/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp"];
            }
            exec { "set mysql for add on":
                command     => "/usr/bin/mysql --user=root --password=$password -NBe \"grant ALL on *.* to 'root'@'%' identified by '$password'\"",
                onlyif      => "/bin/grep export /root/.bashrc",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["packstack-install"];
            }
            exec { "flush privilages":
                command     => "/usr/bin/mysql --user=root --password=$password -NBe  \"flush privileges\"",
                onlyif      => "/bin/grep export /root/.bashrc",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["set mysql for add on"];
            }
          }
          nova_compute: {

            package { "mysql": ensure  => latest; }

            file { "/tmp/packstack-answers.$fqdn":
                mode    => 0644,
                replace => false,
                content => template( "openstack/packstack-answers_nova_compute.erb" ),
                require => Package["openstack-packstack"];
            }
            exec { "node specific answer change":
                command     => "/bin/bash -c \"sed -i 's/$dashboard/`host $dashboard | awk '{print \$4}'`/g' /tmp/packstack-answers.$fqdn \" ",
                onlyif      => "/bin/grep $dashboard /tmp/packstack-answers.$fqdn",
                require     => File["/tmp/packstack-answers.$fqdn"];
            }
            file { "/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp":
                source  => "puppet://puppet/modules/openstack/prescript.pp",
                require => Exec["node specific answer change"];
            }
            exec { "packstack-install":
                environment => [ "HOME=/root"],
                command     => "/usr/bin/packstack --answer-file=/tmp/packstack-answers.$fqdn ",
                timeout     => 7200,
                unless      => "/sbin/chkconfig --list | /bin/grep openstack",
                onlyif      => "/usr/bin/facter | /bin/grep 'gateway =>'",
                require     => File["/usr/lib/python2.6/site-packages/packstack/puppet/templates/prescript.pp"];
            }
          }
        }
    }
}




