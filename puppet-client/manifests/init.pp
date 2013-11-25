

class puppet-client {

            file { "/etc/puppet/namespace.auth":
		ensure  => present, 
                owner   => "root",
                group   => "root",
                mode    => 0644,
                source  => "puppet://puppet/modules/puppet-client/namespace.auth";
            }

}
