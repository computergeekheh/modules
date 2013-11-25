#
#
#
define network_interface($bootproto="static", $ipaddress=$ipaddress, $macaddress=$macaddress, $network=$network, $netmask=$netmask, $gateway=$gateway, $master="", $bonding="", $onboot="yes", $vlan="") {  

  if $bonding != "" {    # Unlikely this place will ever use this, but.....
     file { "/etc/modprobe.d/bonding":
      	content => template("network/bonding.erb"),
        notify  => Exec["service network restart"];
     }
     file { "/etc/sysconfig/network-scripts/ifcfg-$name":
      	content => template("network/ifcfg-bonding.erb"),
      	notify  => Exec["service network restart"],
        require => Exec["facter-kick"];
    }
  }else {
    if $gateway != "" {
     $ip = "ipaddress_$name"
     $mac = "macaddress_$name"
     $mask = "netmask_$name"
      file { "/etc/sysconfig/network-scripts/ifcfg-$name":
       	content => template("network/ifcfg.erb"),
       	notify  => Exec["service network restart"],
        require => Exec["facter-kick"];
      }
    }
  }
}

class network {

    package { 'vconfig': ensure  => latest; }

    file { "/usr/lib/ruby/site_ruby/1.8/facter/gateway.rb":
        ensure  => present,
        mode    => 0655,
        source  => "puppet://puppet/modules/network/gateway.rb",
        require => Package["vconfig"];
    }
    exec { "service network restart":
       	path        => "/bin:/usr/bin:/sbin:/usr/sbin",
       	refreshonly => true,
	onlyif	    => "/usr/bin/facter | /bin/grep 'gateway =>'",
       	require     => Exec["facter-kick"];
    }
    file { "/tmp/gateway":
        ensure  => present,
        mode    => 0655,
        source  => "puppet://puppet/modules/network/gateway",
        require => File["/usr/lib/ruby/site_ruby/1.8/facter/gateway.rb"];
    }
    exec { "facter-kick":
        command => "/tmp/gateway ",
        unless  => "/usr/bin/facter | /bin/grep 'gateway =>'",
        require => File["/tmp/gateway"];
    }
    file { "/etc/sysconfig/network":
        content     => template("network/network.erb"),
        notify      => Exec["hostname $fqdn"],
        require     => Exec["facter-kick"];
    }
    exec { "hostname $fqdn":
        path        => "/bin:/usr/bin:/sbin:/usr/sbin",
        refreshonly => true,
        require     => File["/etc/sysconfig/network"];
    }
}

