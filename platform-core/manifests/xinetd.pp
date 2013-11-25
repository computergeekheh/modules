#
#
#

class xinetd {

   package { xinetd: ensure => latest, require => [Service["puppet"], File["/etc/yum.conf"]];}

   service { xinetd:
      ensure    => running,
      require   => Package["xinetd"];
   }
}

