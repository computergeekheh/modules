#
#
#
class server-config {

   node 'default' {
      include platform-core
   }

   node 'cluster' inherits default {  
	$primary = "ceph03.ncce.com"          					# <== Whether this is the initial cluster creation host
        $disks = ["/dev/cciss/c0d1", "/dev/cciss/c0d2", "/dev/cciss/c0d3"]	# <== Here are the full paths of disks for cluster.			
	$quorum = "ceph03.ncce.com,ceph04.ncce.com,ceph06.ncce.com" 		# <== These are your initial 3 mon servers. You can add mon's below if more are needed
                                                                                       
   	#    openstack_cluster' 							# <== defines global parameters for the openstack system
	$dashboard = "openstack.ncce.com"					# <== dashboard is the horizon server. This should be brought up first.
        $openstack_private_interface = "eth1"
        $openstack_private_ip_range  = "10.10.4.0/22"
        $openstack_floating_ip_range = "10.10.4.0/22"
        $password = "password"                                                  # <== the admin password for the Horizon Dashboard
        $ntp_server = "0.centos.pool.ntp.org"
        $ceph_cluster = "yes"
        $cephfs = "yes"                                                         # <== This will install the cephFS kernel
        $cephfs_mounts = "no"                                                   # <== This will install the cephFS, mount it, and present it to cinder
        $ceph_rdo = "yes"                                                       # <== this will allow Openstack to access the ceph Object Store
        $ceph_rdo_pool_name = "rbd"                                             # <== This will auto creat a pool in the object store. Use the default rbd normally.

  }

   node 'openstack' inherits cluster {
      include ssh-keys
      include openstack
	disk_standard { "standard": }  							# <== 20G swap, the rest on / 
	network_interface {"eth0": bootproto  => "static";  				# <== converts the dhcp to static
			   "eth1": bootproto  => "static",
			           ipaddress  => "10.10.4.1",
			   	   netmask    => "255.255.255.0";}

        openstack_install {"install": install_mode => "all-in-one";}   # <== this will be an all in one install type and support cephfs
        #							       # <== Choices for install_mode are: "all-in-one", "nova_compute", "glance"

  }											

   node /^ceph0[3,4,6]/ inherits cluster {
      include ssh-keys
      include ceph
        disk_standard { "standard": }   
        network_interface  {"eth0": bootproto 	=> "static";}        
        #ceph_install   { "install": role        => "mon";}	###  <<<======   DON'T CALL THESE AS MONS'S IF THEY ARE THE QUORUM  !!  
        ceph_install_disk { $disks: }

   }
   node /^ceph05/ inherits cluster {
      include ssh-keys
      #include ceph
      #include openstack
        disk_standard { "standard": }
        network_interface {"eth0": bootproto => "static";}      		
        #openstack_install {"install": install_mode => "nova_compute";}
        #ceph_install   { "install": role     => "mds" ; }			
        #ceph_install_disk { $disks: }
   }

   node /^ceph07/ inherits cluster {
      include ssh-keys
      #include ceph
      include openstack
        disk_standard { "standard": }
        network_interface {"eth0": bootproto => "static";
                           "eth1": bootproto  => "static",
                                   ipaddress  => "10.10.4.2",
                                   netmask    => "255.255.255.0";}
      
        openstack_install {"install": install_mode => "nova_compute";}
        #ceph_install   { "install": role        => "mon" ; }
        #ceph_install_disk { $disks: }
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


