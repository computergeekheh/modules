

class rdo_openstack::ceph_storage ( $rbd = "ceph" )  {

        case $rbd {

          ceph: {

            exec { "rdo admin prep":
                command     => "/usr/bin/ssh $cluster_head 'ceph-deploy admin $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                #onlyif      => "/usr/bin/ssh $cluster_head 'ceph -s' | /bin/grep cluster ",
                require     => [Package["ceph"], Exec["packstack-install"]];
            }
            exec { "rdo keys prep":
                command     => "/usr/bin/ssh $cluster_head 'ceph-deploy gatherkeys $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                #onlyif      => "/usr/bin/ssh $cluster_head 'ceph -s' | /bin/grep cluster ",
                require     => Exec["rdo admin prep"];
            }
            file { "/etc/cinder/cinder.conf":
                mode    => 0644,
                notify  => Service["openstack-cinder-volume"],
                content => template( "rdo_openstack/cinder.erb" ),
                require => Exec["rdo keys prep"];
            }
            file { "/etc/nova/nova.conf":
                mode    => 0644,
                notify  => Service["openstack-nova-compute"],
                content => template( "rdo_openstack/nova.erb" ),
                require => File["/etc/cinder/cinder.conf"];
            }
            file { "/etc/sysconfig/openstack-cinder-volume":
                mode    => 0644,
                notify  => Service["openstack-cinder-volume"],
                content => template( "rdo_openstack/openstack-cinder-volume.erb" ),
                require => File["/etc/nova/nova.conf"];
            }

        service { "openstack-nova-compute":    ensure => running, require => Exec["packstack-install"]; }
        service { "openstack-cinder-scheduler":    ensure => running, require => Exec["packstack-install"]; }
        service { "openstack-cinder-volume": ensure => running, require => Exec["packstack-install"]; }
        service { "openstack-cinder-api":      ensure => running, require => Exec["packstack-install"]; }

          }
        }
}
