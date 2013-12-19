

class ceph::osd_disks {

}
	define ceph_osd_disk ( ) {

             exec { "gather-keys-$name":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy gatherkeys $fqdn ' ",
                unless      => "/bin/mount | grep ${name} ",
                onlyif      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ' ",
                require     => Class["ceph"];
             }
             exec { "deploy-admin-$name":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy admin $fqdn ' ",
                unless      => "/bin/mount | grep ${name}  ",
                onlyif      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ' ",
                require     => Exec["gather-keys-$name"];
             }
             exec { "zap-disk-$name":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy disk zap $fqdn:${name} ' ",
                unless      => "/bin/mount | grep ${name} ",
                onlyif      => "/usr/bin/ceph -s ",
                require     => Exec["deploy-admin-$name"];
             }
             exec { "osd-create-$name":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy osd create $fqdn:${name} ' ",
                unless      => "/bin/mount | grep ${name} ",
                onlyif      => "/usr/bin/ceph -s ",
                require     => Exec["zap-disk-$name"];
             }
	}
#}
