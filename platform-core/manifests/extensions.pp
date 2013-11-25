#
#
#
class extensions {

   file { "/usr/lib/ruby/site_ruby/1.8/facter/gateway.rb":
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 644,
        source  => "puppet:///platform-core/gateway.rb";
   }
   exec { "ruby-kick":
        command => "/sbin/service network restart",
        unless  => "/usr/bin/facter | /bin/grep 'gateway =>'",
        require => File["/usr/lib/ruby/site_ruby/1.8/facter/gateway.rb"];
   }
   exec { "ruby-done":
	command => "/bin/netstat -rn",
	unless  => "/usr/bin/facter | /bin/grep 'gateway =>'",
	require => Exec["ruby-kick"];
   }
}

