#
#
#
class ntp {

   package { "ntp": ensure => latest, require => File["/etc/ntp.conf"]; }

   service { "ntpd":
      ensure    => running,
      subscribe => File["/etc/ntp.conf"],
      require   => [ Package["ntp"], File["/etc/ntp.conf"] ],
      before    => File["/etc/yum.conf"];
   }
}
define ntp_conf($ntpservers) {
   file { "/etc/ntp.conf": 
      content => template("platform-core/ntp.conf.erb"),
      before  => File["/etc/yum.conf"];
   }
    file { "/etc/ntp/step-tickers":
      content => template("platform-core/ntp-step-tickers.erb"),
      require => [ Service[ "ntpd" ], Package["ntp"] ],
        }
}

