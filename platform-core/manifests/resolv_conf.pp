#
#
#

class resolv_conf {
}

define resolv-conf( $searchpath = "$domain", $nameservers ) {
   file { "/etc/resolv.conf":
      	content => template("platform-core/resolv_conf.erb"),
      	before  => File["/etc/yum.conf"],
        require => Service["puppet"];
   }
}
