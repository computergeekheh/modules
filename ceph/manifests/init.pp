

class ceph {

        package { ['ceph-deploy', 'ceph']: ensure  => latest; }

	$main = inline_template("<%= %x{/usr/bin/host ${dashboard} | awk '{print \$4}'}.chomp %>") 

            file { "/root/.bashrc":
                owner   => "root",
                group   => "root",
                mode    => 0644,
                content => template( "rdo_openstack/bashrc.erb" ),
                require => Package["ceph"];
            }

}
