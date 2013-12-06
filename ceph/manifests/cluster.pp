

class ceph::cluster ( $primary = "", $quorum = "" ) {

	if $primary == "" or $quorum == "" {
	  fail('The Primary server and the initial quorum must be set')
        } else {
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
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy mon create-initial {$quorum} '  ",
                timeout     => 7200,
                onlyif      => "/usr/bin/ssh $primary '/bin/ls /root/ | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $primary '/bin/ls /etc/ceph | grep ceph.conf ' ",
                require     => Exec["install-cluster"];
            }
             exec { "gather-keys":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy gatherkeys {$quorum} ' ",
                onlyif      => "/usr/bin/ssh $primary '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["install-cluster-quorum"];
            }
             exec { "deploy-admin":
                command     => "/usr/bin/ssh $primary '/usr/bin/ceph-deploy admin {$quorum} ' ",
                onlyif      => "/usr/bin/ssh $primary '/bin/ls /etc/ceph | grep ceph.conf ' ",
                unless      => "/usr/bin/ssh $primary '/usr/bin/ceph -s ' ",
                require     => Exec["gather-keys"];
            }
	}

}
