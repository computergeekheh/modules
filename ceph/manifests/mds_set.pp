

class ceph::mds_set {



             exec { "gather-keys-$fqdn":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy gatherkeys $fqdn ' ",
                unless      => "/usr/bin/ceph -s | /bin/grep mdsmap | /bin/grep $fqdn ",
                onlyif      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ' ",
                require     => Class["ceph"];
             }
             exec { "deploy-admin-$fqdn":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy admin $fqdn ' ",
                unless      => "/usr/bin/ceph -s | /bin/grep mdsmap | /bin/grep $fqdn  ",
                onlyif      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ' ",
                require     => Exec["gather-keys-$fqdn"];
             }
             exec { "mds-create-$fqdn":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy mds create $fqdn ' ",
                unless      => "/usr/bin/ceph -s | /bin/grep mdsmap | /bin/grep $fqdn  ",
                onlyif      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ",
                require     => Exec["deploy-admin-$fqdn"];
             }
}
