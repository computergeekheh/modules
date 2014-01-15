

class ceph::cluster ( $quorum = "", $pages = "100", $replicas = "2" ) {

	if $cluster_head == "" or $quorum == "" {
	  fail('The Primary server and the initial quorum must be set')
        } else {
             exec { "time sync":
                command     => "/usr/sbin/ntpdate $ntp_server && /sbin/hwclock -w ",
                onlyif      => "/usr/bin/host $ntp_server ",
                require     => Package["ceph-deploy", "ceph"];
            }
             exec { "install-cluster":
                command     => "/usr/bin/ssh $cluster_head 'ceph-deploy new {$quorum} '  ",
                timeout     => 7200,
                unless      => "/usr/bin/ssh $cluster_head '/bin/ls /root/ | grep ceph.conf ' ",
                require     => Exec["time sync"];
            }
             exec { "install-cluster-quorum":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy mon create-initial {$quorum} '  ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $cluster_head '/bin/ls /root/ | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $cluster_head '/bin/ls /etc/ceph | grep ceph.conf ' ",
                require     => Exec["install-cluster"];
            }
             exec { "gather-keys":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy gatherkeys {$quorum} ' ",
                onlyif      => "/usr/bin/ssh $cluster_head '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ' ",
                require     => Exec["install-cluster-quorum"];
            }
             exec { "deploy-admin":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph-deploy admin {$quorum} ' ",
                onlyif      => "/usr/bin/ssh $cluster_head '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph -s ' ",
                require     => Exec["gather-keys"];
            }
             exec { "set-pages_pg":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph osd pool set rbd pg_num $pages ' ",
                onlyif      => "/usr/bin/ssh $cluster_head '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph osd pool get rbd pg_num | /bin/grep $pages ' ",
                require     => Exec["deploy-admin"];
            }
             exec { "set-pages_pgp":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph osd pool set rbd pgp_num $pages ' ",
		returns     => [0,11],
                onlyif      => "/usr/bin/ssh $cluster_head '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph osd pool get rbd pgp_num | /bin/grep $pages ' ",
                require     => Exec["set-pages_pg"];
            }
             exec { "set-replication":
                command     => "/usr/bin/ssh $cluster_head '/usr/bin/ceph osd pool set rbd size $replicas ' ",
                onlyif      => "/usr/bin/ssh $cluster_head '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $cluster_head '/usr/bin/ceph osd pool get rbd size | /bin/grep $replicas ' ",
                require     => Exec["set-pages_pgp"];
            }
	}

}
