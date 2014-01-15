

class rdo_openstack::compute_node {

        package { "openstack-nova": 		   ensure  => latest; }
        package { "openstack-nova-compute": 	   ensure  => latest; }
        package { "openstack-cinder": 		   ensure  => latest; }
        package { "python-cinderclient": 	   ensure  => latest; }
        package { "openstack-neutron": 		   ensure  => latest; }
        package { "openstack-neutron-openvswitch": ensure  => latest; }
        package { "iproute": 			   ensure  => latest; }
        package { "openvswitch": ensure => latest, require => Package["iproute"]; } 

        service { "openvswitch":        	ensure => running, enable => true, require => Package["openvswitch"]; }
        service { "neutron-l3-agent":   	ensure => running, enable => true, require => Package["openstack-neutron"]; }
        service { "neutron-dhcp-agent": 	ensure => running, enable => true, require => Package["openstack-neutron"]; }
        service { "neutron-metadata-agent": 	ensure => running, enable => true, require => Package["openstack-neutron"]; }
#        service { "neutron-server":          	ensure => running, enable => true, require => Package["openvswitch"]; }



            file { "/etc/neutron/l3_agent.ini":
		owner	    => "root",
		group	    => "neutron",
                notify      => Service["neutron-l3-agent"],
                source      => "puppet:///modules/rdo_openstack/l3_agent.ini",
                require     => Package["openstack-neutron"];
            }
            file { "/etc/neutron/neutron.conf":
                owner       => "root",
                group       => "neutron",
                notify      => Service["neutron-dhcp-agent"],
                content     => template( "rdo_openstack/neutron.conf.erb" ),
                require     => Package["openstack-neutron"];
            }
            file { "/etc/neutron/dhcp_agent.ini":
                owner       => "root",
                group       => "neutron",
                notify      => Service["neutron-dhcp-agent"],
                source      => "puppet:///modules/rdo_openstack/dhcp_agent.ini",
                require     => Package["openstack-neutron"];
            }
            exec { "add br-int":
                command     => "/usr/bin/ovs-vsctl add-br br-int ",
                unless      => "/sbin/ifconfig | /bin/grep br-int ",
                require     => Service["openvswitch"];
            }
            exec { "add br-ex":
                command     => "/usr/bin/ovs-vsctl add-br br-ex ",
                unless      => "/sbin/ifconfig | /bin/grep br-ex ",
                require     => Service["openvswitch"];
            }

}
