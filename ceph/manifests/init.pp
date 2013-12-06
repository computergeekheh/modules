

class ceph {

        package { ['ceph-deploy', 'ceph']: ensure  => latest; }

            file { "/opt/fdisk.del":
                source  => "puppet:///modules/ceph/fdisk.del",
            }
            file { "/opt/fdisk.ceph":
                source  => "puppet:///modules/ceph/fdisk.ceph",
            }


}
