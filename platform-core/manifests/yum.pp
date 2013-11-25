class yum {

   package { yum: ensure => latest, require => Service["puppet"]; }

   file { "/etc/yum.conf":
        owner   => root,
        group   => root,
        mode    => 640,
        content => template("platform-core/yum.conf.erb"),
        require => Package["yum"];
   }
   file { "/etc/yum.repos.d":
      ensure      => absent,
      recurse     => true,
      force       => true,
      require     => Package["yum"], 
      before      => File["/etc/yum.conf"];
   }
   exec { "yum clean all":
        command => "/usr/bin/yum clean all",
        require => File["/etc/yum.conf"];
   }
}

