#
#
#
class authkeys {

   file { "/root/.ssh":
        ensure  => directory,
        owner   => root,
        group   => root,
        mode    => 644,
        require  => Exec["ruby-done"];
   }
   file { "/etc/ssh/ssh_config":
	ensure	=> present,
        owner   => root,
        group   => root,
        mode    => 644,
        source	=> "puppet:///platform-core/ssh_config",
	require => File["/root/.ssh"];
   }
   file { "/root/.ssh/authorized_keys2":
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 644,
        source  => "puppet:///platform-core/authorized_keys2",
        require => File["/etc/ssh/ssh_config"];
   }
   exec { "keys - done":
	command => "/bin/echo 'keys done'",
	require => File["/root/.ssh/authorized_keys2"];
   }
}
