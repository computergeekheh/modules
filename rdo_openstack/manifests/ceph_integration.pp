

class rdo_openstack::ceph_integration ( $ceph = "rbd", $ceph_rdo_pool_name = "rbd", $ceph_images_pool_name = "images", $virsh_uuid = "$virsh_uuid" ) {

        case $ceph {

          rbd: {
            exec { "rdo admin prep":
                command     => "/usr/bin/ssh $cluster_head 'ceph-deploy admin $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                require     => Class["rdo_openstack::install"];
            }
            exec { "rdo keys prep":
                command     => "/usr/bin/ssh $cluster_head 'ceph-deploy gatherkeys $hostname' ",
                unless      => "/usr/bin/ceph -s ",
                require     => Exec["rdo admin prep"];
            }
            exec { "glance images pool":
                command     => "/usr/bin/rados mkpool $ceph_images_pool_name ",
                unless      => "/usr/bin/rados lspools | grep $ceph_images_pool_name ",
                onlyif      => "/usr/bin/ceph -s ",
                require     => Exec["rdo keys prep"];
            }
            file { "/opt/secret.xml":
                ensure      => present,
                mode        => 0655,
                source      => "puppet:///modules/rdo_openstack/secret.xml",
                require     => Exec["glance images pool"];
            }
            exec { "libvert define secrets":
                command     => "/usr/bin/virsh secret-define --file /opt/secret.xml ",
                unless      => "/usr/bin/virsh secret-list | /bin/grep Unused ",
                onlyif      => "/bin/ls /opt/secret.xml ",
                require     => File["/opt/secret.xml"];
            }
            exec { "libvert secrets":
                command     => "/usr/bin/virsh secret-set-value --secret `/usr/bin/virsh secret-list | /bin/grep Unused | awk '{print \$1}'` --base64 `/usr/bin/ceph auth list | /bin/grep -A 1 client.admin | awk '{print \$2}'` ",
                unless      => "/usr/bin/virsh secret-get-value `/usr/bin/virsh secret-list | /bin/grep Unused | awk '{print \$1}'` ",
                onlyif      => "/bin/ls /opt/secret.xml ",
                require     => [Service["libvirtd"], Exec["libvert define secrets"]];
            }
            file { "/usr/lib/ruby/site_ruby/1.8/facter/virsh_uuid.rb":
                ensure      => present,
                mode        => 0655,
                source      => "puppet:///modules/rdo_openstack/virsh_uuid.rb",
                require     => Exec["libvert secrets"];
            }
            file { "/etc/cinder/cinder.conf":
                mode        => 0644,
                notify      => Service["openstack-cinder-volume"],
                content     => template( "rdo_openstack/cinder.erb" ),
                require     => File["/usr/lib/ruby/site_ruby/1.8/facter/virsh_uuid.rb"];
            }
            file { "/etc/nova/nova.conf":
                mode        => 0644,
                notify      => Service["openstack-nova-compute"],
                content     => template( "rdo_openstack/nova.erb" ),
                require     => File["/etc/cinder/cinder.conf"];
            }
            file { "/etc/nova/api-paste.ini":
                mode        => 0644,
                notify      => Service["openstack-nova-api"],
                content     => template( "rdo_openstack/nova_api-paste.ini.erb" ),
                require     => File["/etc/nova/nova.conf"];
            }
            file { "/usr/lib/python2.6/site-packages/qpid/messaging/driver.py":
                source      => "puppet:///modules/rdo_openstack/messaging_driver.py",
                require     => File["/etc/nova/api-paste.ini"];
            }
            file { "/usr/lib/python2.6/site-packages/cinder/volume/driver.py":
                source      => "puppet:///modules/rdo_openstack/volume_driver.py",
                require     => File["/usr/lib/python2.6/site-packages/qpid/messaging/driver.py"];
            }
            file { "/etc/sysconfig/openstack-cinder-volume":
                mode        => 0644,
                notify      => Service["openstack-cinder-scheduler"],
                content     => template( "rdo_openstack/openstack-cinder-volume.erb" ),
                require     => File["/usr/lib/python2.6/site-packages/cinder/volume/driver.py"];
            }

 	      package { "openstack-nova-api":         ensure  => latest; }

              service { "openstack-nova-compute":     ensure => running, enable => true, require => Class["rdo_openstack::install"]; }
              service { "openstack-cinder-scheduler": ensure => running, enable => true, require => Class["rdo_openstack::install"]; }
              service { "openstack-cinder-volume":    ensure => running, enable => true, require => Class["rdo_openstack::install"]; }
              service { "openstack-nova-api":         ensure => running, enable => true, require => [Package["openstack-nova-api"], Class["rdo_openstack::install"]]; }
              service { "libvirtd":                   ensure => running, enable => true; } 
          }
        }
}
