#
#
#
class puppetd {

   file { "/etc/puppet/namespaceauth.conf":
    	content => template("platform-core/namespaceauth.conf.erb"),
	ensure => present,
       	notify  => Service ["puppet"],
	require => Exec["keys - done"];
   }
   file { "/etc/rc.d/rc.local":
        source  => "puppet:///platform-core/rc.local",
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 755,
        require => File["/etc/puppet/namespaceauth.conf"];
   }
   file { "/etc/sysconfig/puppet":
        content => template("platform-core/puppet.erb"),
        ensure => present,
        notify  => Service ["puppet"],
        require => File["/etc/rc.d/rc.local"];
   }	
   service { "puppet": ensure => running, require => File["/etc/sysconfig/puppet"];}

}

