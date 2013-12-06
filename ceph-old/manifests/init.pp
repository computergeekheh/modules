#
class ceph {

            package { "kernel-uek-3.8.13-16.2.1.el6uek": ensure  => present; }

            file { "/boot/grub/grub.conf":
                owner       => "root",
                group       => "root",
                mode        => 0600,
                content     => template( "ceph/grub.erb" ),
                require     => Package["kernel-uek-3.8.13-16.2.1.el6uek"];
            }
            exec { "kernel-reboot":
                command     => "/sbin/reboot ",
                unless      => "/bin/uname -r | /bin/grep 3.8.13-16.2.1.el6uek.x86_64 ",
                require     => File["/boot/grub/grub.conf"];
            }

        package { ['ceph-deploy', 'ceph']: ensure  => latest, require => Exec["kernel-reboot"]; }

             exec { "time sync":
                command     => "/usr/sbin/ntpdate $ntp_server ",
                onlyif      => "/usr/bin/host $ntp_server ",
                require     => Package["ceph-deploy", "ceph"];
            }
             exec { "install-cluster":
                command     => "/usr/bin/ssh $primary 'ceph-deploy new {$quorum} '  ",
                timeout     => 7200,
                unless      => "/usr/bin/ssh $primary '/bin/ls /root/ | grep ceph.conf ' ",
                require     => Exec["time sync"];
            }
             exec { "install-cluster-quorum":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy mon create {$quorum} '  ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $primary '/bin/ls /root/ | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $primary '/bin/ls /etc/ceph | grep ceph.conf ' ",
                require     => Exec["install-cluster"];
            }
             exec { "gather-keys":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy gatherkeys $primary ' ",
                onlyif      => "/usr/bin/ssh $primary '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["install-cluster-quorum"];
            }
            file { "/opt/fdisk.del":
                source  => "puppet:///modules/ceph/fdisk.del",
                require     => Exec["gather-keys"];
            }
            file { "/opt/fdisk.ceph":
                source  => "puppet:///modules/ceph/fdisk.ceph",
                require     => File["/opt/fdisk.del"];
            }
}
define ceph_install ( $role="none" ) {

             exec { "install-$role":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy $role create $fqdn ' ",
                timeout     => 7200,
                unless      => "/usr/bin/ssh $primary '/usr/bin/ceph -s | /bin/grep $role\map | /bin/grep $hostname ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["install-cluster-quorum"];
            }
             exec { "gather-keys-$role":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy gatherkeys $fqdn ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                unless      => "/usr/bin/ssh $primary '/usr/bin/ceph -s | /bin/grep $role\map | /bin/grep $hostname ' ",
                require     => Exec["install-$role"];
            }
             exec { "deploy-admin-$role":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy admin $fqdn ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                unless      => "/usr/bin/ssh $primary '/usr/bin/ceph -s | /bin/grep $role\map | /bin/grep $hostname ' ",
                require     => Exec["gather-keys-$role"];
             }
	
}
define ceph_install_disk ( $disks="none" ) {

             exec { "fdisk-clear-$name":
                command     => "/sbin/fdisk $name < /opt/fdisk.del ",
                unless      => "/usr/bin/ssh $fqdn '/bin/mount | grep $name\1 ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => File["/opt/fdisk.ceph"];
            }
             exec { "fdisk-set-$name":
                command     => "/sbin/fdisk $name < /opt/fdisk.ceph ",
                unless      => "/usr/bin/ssh $fqdn '/bin/mount | grep $name\1 ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["fdisk-clear-$name"];
            }
	     exec { "zap-disk-$name":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy disk zap $fqdn:$name\1 ' ",
                timeout     => 7200,
                unless      => "/usr/bin/ssh $fqdn '/bin/mount | grep $name\1 ' ",
		onlyif 	    => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["fdisk-set-$name"];
             }
             exec { "gather-keys-$name":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy gatherkeys $fqdn ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                unless      => "/usr/bin/ssh $fqdn '/bin/mount | grep $name\1 ' ",
		# for some reson, it needs to sync the keys one more time.. so we will just do this
                require     => Exec["zap-disk-$name"];
             }
             exec { "deploy-admin-$name":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy admin $fqdn ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                unless      => "/usr/bin/ssh $fqdn '/bin/mount | grep $name\1 ' ",
                require     => Exec["gather-keys-$name"];
             }
             exec { "osd-create-$name":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy osd create $fqdn:$name\1 ' ",
                timeout     => 7200,
                unless      => "/usr/bin/ssh $fqdn '/bin/mount | grep $name\1 ' ",
                onlyif      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["deploy-admin-$name"];
             }
}

