

class ceph::kernel ( $ceph_kernel = "kernel-uek", $ceph_kernel_version = "3.8.13-16.2.1.el6uek.x86_64" ) {

            package { "$ceph_kernel-$ceph_kernel_version": ensure  => present }

            file { "/boot/grub/grub.conf":
                owner       => "root",
                group       => "root",
                mode        => 0600,
                content     => template( "ceph/grub.erb" ),
                require     => Package["$ceph_kernel-$ceph_kernel_version"];
            }
	if $::kernelrelease != $ceph_kernel_version {
            exec { "kernel-reboot":
                command     => "/sbin/reboot ",
                require     => File["/boot/grub/grub.conf"];
            }
	}
}
