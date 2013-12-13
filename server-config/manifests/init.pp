#
#
#
class server-config {

   node 'default' {
      include platform-core
   }

   node 'cluster' inherits default {  
                                                                                       
 	$cluster_head = "ceph01.athenalab.athenahealth.com"
   	#    openstack_cluster' 							# <== defines global parameters for the openstack system
	$dashboard = "openstack.athenalab.athenahealth.com"				# <== dashboard is the horizon server. This should be brought up first.
        $openstack_private_ip_range  = "10.10.4.0/22"
        $openstack_floating_ip_range = "10.10.4.0/22"
        $password = "password"                                                  # <== the admin password for the Horizon Dashboard
        $ntp_server = "0.rhel.pool.ntp.org"
        $ceph_cluster = "yes"
        $cephfs = "no"                                                         # <== This will install the cephFS kernel
        $cephfs_mounts = "no"                                                   # <== This will install the cephFS, mount it, and present it to cinder
        $ceph_rdo = "yes"                                                       # <== this will allow Openstack to access the ceph Object Store
        $ceph_rdo_pool_name = "rbd"                                             # <== This will auto creat a pool in the object store. Use the default rbd normally.

  }

   node 'openstack' inherits cluster {
      include ssh-keys
      include ceph
      include rdo_openstack
        class {'rdo_openstack::install': install_mode => 'all-in-one', openstack_private_interface => 'em2', rbd => 'ceph';}
        class {'ceph::kernel': ceph_kernel   => 'kernel-uek', ceph_kernel_version => '3.8.13-16.2.1.el6uek.x86_64';}
	disk_standard { "standard": }  							# <== 20G swap, the rest on / 
	network_interface {"em1": bootproto   => "static";  				# <== converts the dhcp to static
			   "em2": bootproto   => "static",
			           ipaddress  => "10.10.4.1",
			   	   netmask    => "255.255.255.0";}


  }											

   node /^ceph0[1,2,3]/ inherits cluster {
      include ssh-keys
      include ceph
      include ceph::osd_disks
      #include ceph::kernel
        #class {'ceph::kernel': ceph_kernel => 'kernel', ceph_kernel_version => '2.6.32-358.el6.x86_64';}
        class {'ceph::kernel': ceph_kernel   => 'kernel-uek', ceph_kernel_version => '3.8.13-16.2.1.el6uek.x86_64';}
        class {'ceph::cluster': quorum       => "ceph01.athenalab.athenahealth.com,ceph02.athenalab.athenahealth.com,ceph03.athenalab.athenahealth.com", primary => 'ceph01.athenalab.athenahealth.com';}
	ceph_osd_disk {'/dev/sdb':; '/dev/sdc':; '/dev/sdd':; }
        disk_standard { "standard": }   
        network_interface  {"em1": bootproto => "static";}        

   }
   node /^ceph0[4,5]/ inherits cluster {
      include ssh-keys
      include ceph
      include ceph::osd_disks
        class {'ceph::kernel': ceph_kernel   => 'kernel-uek', ceph_kernel_version => '3.8.13-16.2.1.el6uek.x86_64';}
        ceph_osd_disk {'/dev/sdb':; '/dev/sdc':; '/dev/sdd':; '/dev/sde':; '/dev/sdf':;}
        disk_standard { "standard": }
        network_interface {"em1": bootproto => "static";}      		
        #openstack_install {"install": install_mode => "nova_compute";}
        #ceph_install   { "install": role     => "mds" ; }			
   }

   node /^compute01/ inherits cluster {
      include ssh-keys
      include ceph
      include rdo_openstack
      include ceph::kernel
        #class {'rdo_openstack::install': install_mode => 'nova_compute', openstack_private_interface => 'em2';}
        disk_standard { "standard": }
        network_interface {"em1": bootproto   => "static";}
     
 
        #openstack_install {"install": install_mode => "nova_compute";}
        #ceph_install   { "install": role        => "mon" ; }
        #ceph_install_disk { $disks: }
  }
   node /^compute02/ inherits cluster {
      include ssh-keys
      #include ceph
      #include rdo_openstack
        #class {'rdo_openstack::install': install_mode => 'nova_compute', openstack_private_interface => 'em2';}
        disk_standard { "standard": }
        network_interface {"em1": bootproto   => "static";
                           "em2": bootproto   => "static",
                                   ipaddress  => "10.10.4.3",
                                   netmask    => "255.255.255.0";}
  }
   node /^compute03/ inherits cluster {
      include ssh-keys
      #include ceph
      #include openstack
        disk_standard { "standard": }
        network_interface {"em1": bootproto   => "static";
                           "em2": bootproto   => "static",
                                   ipaddress  => "10.10.4.4",
                                   netmask    => "255.255.255.0";}
  }

}

## EXAMPLES: 

#	DISK Setup
#
#   disk_conf {
#                "swap" :
#                    mountpoint => "swap",
#                    filesystem => "swap",
#                    size       => "10485760",
#                    prior      => "opt";
#                "opt"  :
#                    mountpoint => "opt",
#                    filesystem => "ext4",
#                    size       => "20971520",
#                    prior      => "root";
#                "root" :
#                    mountpoint => "/",
#                    size       => "-1";
#            }

#   $forwarders = "10.30.20.10"
#   resolv-conf { "resolv.conf": nameservers => ['puppetmaster_nameserver', '10.30.20.10']}
#   network_interface {"eth0": bootproto => "static";}

   # /etc/ntp.conf configuration - comma sepparated list. Add as needed
#   ntp_conf { "ntp_conf" :
#      ntpservers => ['puppet']
#   }
#
#   for bonding

#network_interface {
#      "eth0":
#          bootproto         => "none",
#          master            => "bond0";
#      "eth1":
#          bootproto         => "none",
#          master            => "bond0";
#      "bond0":
#          bootproto         => "static",
#          bonding           => "mode=4 miimon=100",
#          #macaddress        => $macaddress,
#          ipaddress         => $ipaddress,
#          netmask           => $netmask,
#          gateway           => "10.48.141.1";
#
#        }
#   for trunking 
#
#   network_interface {
#      "eth0.141":
#          bootproto         => "static",
#          ipaddress         => "10.48.141.2",
#          netmask           => "255.255.255.0",
#          vlan              => "141";
#      "eth0.92":
#          bootproto         => "static",
#          ipaddress         => "10.48.92.231",
#          netmask           => "255.255.255.0",
#          vlan              => "92";
#     "eth0.89":
#          bootproto         => "static",
#          ipaddress         => "10.48.89.58",
#          netmask           => "255.255.255.0",
#          vlan              => "89",
#          gateway           => "10.48.89.1";
#}


