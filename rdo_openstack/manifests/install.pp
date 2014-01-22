
class rdo_openstack::install ($install_mode = "none", $openstack_private_interface = "" ) {

    $ip_int = "ipaddress_$openstack_private_interface"  # if more than one network.. most often used.
    $ip = (inline_template("<%= scope[@ip_int] %>"))

            file { "/etc/neutron":
                ensure  => directory,
                require => Package["openstack-packstack"];
            }
            file { "/etc/neutron/api-paste.ini":
                content => template( "rdo_openstack/neutron_api-paste.ini.erb" ),
                require => File["/etc/neutron"];
            }

    if $openstack_private_interface and !$ip  {    # if this hasn't been set, simply do recipe or if set, be sure it's up or do everything but this and catch it later.
      notify {'Networking needs to be done first, delaying OpenStack install':} 
    } else { # Templat will fail if refferenced em2 and it doen't exist
    
        case $install_mode {

          all-in-one: {
            file { "/opt/packstack-answers.$fqdn":
                owner   => "root",
                group   => "root",
                mode    => 0644,
                content => template( "rdo_openstack/packstack-answers_all_in_one.erb" ),
                require => Package["openstack-packstack"];
            }
            exec { "packstack-install":
                environment => [ "HOME=/root"],
                command     => "/usr/bin/packstack --answer-file=/opt/packstack-answers.$fqdn ",
                timeout     => 7200,
                unless      => "/bin/rpm -qa | /bin/grep openstack-dashboard",
                onlyif      => "/usr/bin/facter | /bin/grep 'gateway =>'",
                require     => File["/opt/packstack-answers.$fqdn"];
            }
            exec { "set mysql for services":
                command     => "/usr/bin/mysql --user=root --password=$password -NBe \"grant ALL on *.* to 'root'@'%' identified by '$password'\"",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["packstack-install"];
            }
            exec { "set mysql for add on":
                command     => "/usr/bin/mysql --user=root --password=$password -NBe \"grant ALL on *.* to 'keystone'@'%' identified by '$password'\"",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["set mysql for services"];
            }
            exec { "flush privilages":
                command     => "/usr/bin/mysql --user=root --password=$password -NBe  \"flush privileges\"",
                unless      => "/usr/bin/mysql --host=$ipaddress --user=root --password=$password",
                require     => Exec["set mysql for add on"];
            }
          }
          nova_compute: {

            package { "mysql": ensure  => latest; }

	    include rdo_openstack::compute_node

#            file { "/opt/packstack-answers.$fqdn":
#                mode    => 0644,
#                replace => false,
#                content => template( "rdo_openstack/packstack-answers_nova_compute.erb" ),
#                require => Package["openstack-packstack"];
#            }
#            exec { "node specific answer change":
#                command     => "/bin/bash -c \"sed -i 's/$dashboard/`host $dashboard | awk '{print \$4}'`/g' /opt/packstack-answers.$fqdn \" ",
#                onlyif      => "/bin/grep $dashboard /opt/packstack-answers.$fqdn",
#                require     => File["/opt/packstack-answers.$fqdn"];
#            }
#            exec { "packstack-install":
#                environment => [ "HOME=/root"],
#                command     => "/usr/bin/packstack --answer-file=/opt/packstack-answers.$fqdn ",
#                timeout     => 7200,
#                unless      => "/sbin/chkconfig --list | /bin/grep openstack",
#                onlyif      => "/usr/bin/facter | /bin/grep 'gateway =>'",
#                require     => Exec["node specific answer change"];
#            }
          }
	  none: {
	    fail('class rdo_openstack::install has FAILED !! due to not setting install_mode... Please specify install_mode.  ')
	  }
	}
    }
}
