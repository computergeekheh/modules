#
#
#
class disk-config {
      if ($filesystem == "xfs") {
          $packagelist = ["lvm2", "kmod-xfs", "xfsprogs"]
          package { $packagelist: ensure  => latest,
#          require  => File["/etc/yum.conf"];
        }
      } else {
        package { "lvm2": ensure  => latest,
#	require  => File["/etc/yum.conf"];
	}
      }

    file {"/tmp/fdisk.default":
        owner    => 'root',
        group    => 'root',
        mode     => '755',
        ensure   => present,
        source   => "puppet:///modules/disk-config/fdisk.default",
#	require  => Service["puppet"];
    }
}
define disk_conf($second_controller = "none", $volgroup = "vg1", $mountpoint = "none", $filesystem = "ext4", $size, $prior = "none") {
    $sizek = sprintf("%dk",$size)
        if ($size != "-1") {
            exec { "fdisk_block_device/$title":
                command  => "fdisk $second_controller < /tmp/fdisk.default",
                path     => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless   => "fdisk -l | /bin/grep $second_controller | /bin/grep Linux",
                onlyif   => "fdisk -l | /bin/grep $second_controller",
                require  => File["/tmp/fdisk.default"];
            }
            exec { "create_pv/$title":
                command  => "pvcreate $second_controller'p1'",
                path     => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless   => "pvdisplay | /bin/grep $second_controller ",
                onlyif   => "fdisk -l | /bin/grep $second_controller",
                require  => Exec ["fdisk_block_device/$title"];
            }
            exec { "create_volgroup/$title":
                command  => "vgcreate /dev/$volgroup $second_controller'p1'",
                path     => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless   => "vgdisplay | /bin/grep $volgroup",
                onlyif   => "fdisk -l | /bin/grep $second_controller",
                require  => Exec ["create_pv/$title"];
            }
            exec { "lv-$volgroup/$title":
                command => "lvcreate -L $sizek -n $title $volgroup",
                path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless  => "lvdisplay --units k /dev/$volgroup/$title",
                require => Exec["create_volgroup/$title"],
                before  => $prior ? { "none" => undef, default => Exec["lv-$volgroup/$prior"] };
            }
            exec { "lv-$volgroup/$title-size-le-$size":
                command => "/bin/echo logical volume $volgroup/$title is bigger than $size - can't resize automatically && false",
                path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                onlyif  => "test `lvdisplay --units k /dev/$volgroup/$title|grep Size|cut -b 25-|cut -d . -f 1` -gt $size",
                require => Exec["lv-$volgroup/$title"];
            }
            exec { "lv-$volgroup/$title-size-$size":
                command => "lvresize -L $sizek -n /dev/$volgroup/$title",
                path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless  => "test `lvdisplay --units k /dev/$volgroup/$title|grep Size|cut -b 25-|cut -d . -f 1` -eq $size",
                require => Exec["lv-$volgroup/$title-size-le-$size" ],
                before  => $prior ? { "none" => undef, default => Exec["lv-$volgroup/$prior"] };
            }
        } else {
            exec { "fdisk_block_device/$title":
                command  => "fdisk $second_controller < /tmp/fdisk.default",
                path     => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless   => "fdisk -l | /bin/grep $second_controller | /bin/grep Linux",
                onlyif   => "fdisk -l | /bin/grep $second_controller",
                require  => File["/tmp/fdisk.default"];
            }
            exec { "create_pv/$title":
                command  => "pvcreate $second_controller'p1'",
                path     => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless   => "pvdisplay | /bin/grep $second_controller ",
                onlyif   => "fdisk -l | /bin/grep $second_controller",
                require  => Exec ["fdisk_block_device/$title"];
            }
            exec { "create_volgroup/$title":
                command  => "vgcreate /dev/$volgroup $second_controller'p1'",
                path     => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless   => "vgdisplay | /bin/grep $volgroup",
                onlyif   => "fdisk -l | /bin/grep $second_controller",
                require  => Exec ["create_pv/$title"];
            }
            exec { "lv-$volgroup/$title":
                command => "lvcreate -L `vgdisplay $volgroup|grep 'Free  PE'|cut -b 25-|cut -d ' ' -f 1` -n $title $volgroup",
                path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                unless  => "lvdisplay --units k /dev/$volgroup/$title",
                require => Exec["create_volgroup/$title"],
                before  => $prior ? { "none" => undef, default => Exec["lv-$volgroup/$prior"] };
            }
           exec { "lv-$volgroup/$title-size-$size":
		command => "lvextend -L +\$[`(vgdisplay $volgroup | /bin/grep 'Free  PE' | /bin/awk '{print \$5}')` * `(vgdisplay $volgroup | /bin/grep 'PE Size'|/bin/awk '{print \$3}' | /bin/sed 's/.00//g')`] /dev/$volgroup/$title",
                path    => "/bin:/usr/bin:/sbin:/usr/sbin",
                unless  => "test `vgdisplay $volgroup|grep 'Free  PE'|cut -b 25-|cut -d ' ' -f 1` -eq 0",
                require => Exec["lv-$volgroup/$title"],
                before  => $prior ? { "none" => undef, default => Exec["lv-$volgroup/$prior"] };
            }
        }
#----------------------------------------- LV's are done now... let's deal with file system now ------------------------------------
        case $filesystem {
            ext3: {
                if ($size != "-1") {
                    exec { "mkfs-ext3-$volgroup/$title":
                        command => "/sbin/mkfs.ext3 /dev/$volgroup/$title",
                        path    => "/bin:/usr/bin:/sbin",
                        unless  => "/sbin/tune2fs -l /dev/$volgroup/$title",
                        timeout => 3600,
                        require => Exec["lv-$volgroup/$title-size-$size"];
                    }
                    exec { "size-ext3-$volgroup/$title-le-$size":
                        command => "/bin/echo filesystem $volgroup/$title is bigger than $size - can't resize automatically && false",
		  	onlyif  => "/usr/bin/test \$[`(tune2fs -l /dev/$volgroup/$title |/bin/grep -i '^Block Count'|cut -b 27-)` * `(tune2fs -l /dev/$volgroup/$title|/bin/grep -i '^Block size'|cut -b 27-)` /1024 ] -gt $size",
                        path    => "/bin:/usr/bin:/sbin",
                        require => Exec["mkfs-ext3-$volgroup/$title"];
                    }
                    exec { "size-ext3-$volgroup/$title":
                        command => "/sbin/resize2fs /dev/$volgroup/$title $sizek",
                        path    => "/bin:/usr/bin:/sbin",
			unless  => "/usr/bin/test \$[`(tune2fs -l /dev/$volgroup/$title |/bin/grep -i '^Block Count'|cut -b 27-)` * `(tune2fs -l /dev/$volgroup/$title|/bin/grep -i '^Block size'|cut -b 27-)` /1024 ] -ge $size",
                        timeout => 3600,
                        require => Exec["size-ext3-$volgroup/$title-le-$size"];
                    }
                   exec { "ensure$mountpoint":
                        command => "/bin/mkdir -p $mountpoint",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/ls $mountpoint",
                        require => Exec["size-ext3-$volgroup/$title"];
                   }
                    exec { "fstab-$volgroup/$title":
                        command => "/bin/echo '/dev/$volgroup/$title         $mountpoint                     $filesystem    defaults        1 2' >> /etc/fstab",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/cat /etc/fstab | /bin/grep $title && /bin/cat /etc/fstab | /bin/grep '$mountpoint '",
                        require => Exec["ensure$mountpoint"];
                    }
                    exec { "mount-$volgroup/$title":
                        command => "/bin/mount -a ; rm -rf /$mountpoint/lost+found",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/mount | grep /dev/mapper/$volgroup-$title",
                        require => Exec["fstab-$volgroup/$title"];
                    }
              } else {
                    exec { "mkfs.ext3-$volgroup/$title":
                        command => "/sbin/mkfs.ext3 /dev/$volgroup/$title",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "tune2fs -l /dev/$volgroup/$title | grep clean",
                        timeout => 3600,
                        require => Exec["lv-$volgroup/$title-size-$size"];
                    }
                    exec { "size-ext3-$volgroup/$title":
                        command => "/sbin/resize2fs -p /dev/$volgroup/$title",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
			unless  => "/usr/bin/test \$[`(lvdisplay /dev/$volgroup/$title --units k | /bin/grep 'LV Size' | /bin/awk '{print \$3}' | /bin/sed 's/.00//g')`] -eq \$[`(tune2fs -l /dev/$volgroup/$title |/bin/grep -i '^Block Count'|awk '{print \$3}')` * `(tune2fs -l /dev/$volgroup/$title|/bin/grep -i '^Block size'| /bin/awk '{print \$3}')` /1024 ]", 
                        timeout => 3600,
                        require => Exec["mkfs.ext3-$volgroup/$title"];
                    }
                   exec { "ensure$mountpoint":
                        command => "/bin/mkdir -p $mountpoint",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/ls $mountpoint",
                        require => Exec["size-ext3-$volgroup/$title"];
                   }
                    exec { "fstab-$volgroup/$title":
                        command => "/bin/echo '/dev/$volgroup/$title    $mountpoint                     $filesystem    defaults        1 2' >> /etc/fstab",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/cat /etc/fstab | /bin/grep $title && /bin/cat /etc/fstab | /bin/grep '$mountpoint '",
                        require => Exec["ensure$mountpoint"];
                    }
                    exec { "mount-$volgroup/$title":
                        command => "/bin/mount -a ; rm -rf /$mountpoint/lost+found",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/mount | /bin/grep /dev/mapper/$volgroup-$title",
                        require => Exec["fstab-$volgroup/$title"];
                    }
              }
	}
 	ext4: {
                if ($size != "-1") {
                    exec { "mkfs-ext4-$volgroup/$title":
                        command => "/sbin/mkfs.ext4 /dev/$volgroup/$title",
                        path    => "/bin:/usr/bin:/sbin",
                        unless  => "/sbin/tune2fs -l /dev/$volgroup/$title",
                        timeout => 3600,
                        require => Exec["lv-$volgroup/$title-size-$size"];
                    }
                    exec { "size-ext4-$volgroup/$title-le-$size":
                        command => "/bin/echo filesystem $volgroup/$title is bigger than $size - can't resize automatically && false",
                        onlyif  => "/usr/bin/test \$[`(tune2fs -l /dev/$volgroup/$title |/bin/grep -i '^Block Count'|cut -b 27-)` * `(tune2fs -l /dev/$volgroup/$title|/bin/grep -i '^Block size'|cut -b 27-)` /1024 ] -gt $size",
                        path    => "/bin:/usr/bin:/sbin",
                        require => Exec["mkfs-ext4-$volgroup/$title"];
                    }
                    exec { "size-ext4-$volgroup/$title":
                        command => "/sbin/resize2fs /dev/$volgroup/$title $sizek",
                        path    => "/bin:/usr/bin:/sbin",
                        unless  => "/usr/bin/test \$[`(tune2fs -l /dev/$volgroup/$title |/bin/grep -i '^Block Count'|cut -b 27-)` * `(tune2fs -l /dev/$volgroup/$title|/bin/grep -i '^Block size'|cut -b 27-)` /1024 ] -ge $size",
                        timeout => 3600,
                        require => Exec["size-ext4-$volgroup/$title-le-$size"];
                    }
                   exec { "ensure-ext4-$mountpoint":
                        command => "/bin/mkdir -p $mountpoint",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/ls $mountpoint",
                        require => Exec["size-ext4-$volgroup/$title"];
                   }
                    exec { "fstab-ext4-$volgroup/$title":
                        command => "/bin/echo '/dev/$volgroup/$title         $mountpoint                     $filesystem    defaults        1 2' >> /etc/fstab",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/cat /etc/fstab | /bin/grep $title && /bin/cat /etc/fstab | /bin/grep '$mountpoint '",
                        require => Exec["ensure-ext4-$mountpoint"];
                    }
                    exec { "mount-$volgroup/$title":
                        command => "/bin/mount -a ; rm -rf /$mountpoint/lost+found",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/mount | grep /dev/mapper/$volgroup-$title",
                        require => Exec["fstab-ext4-$volgroup/$title"];
                    }
              } else {
                    exec { "mkfs.ext4-$volgroup/$title":
                        command => "/sbin/mkfs.ext4 /dev/$volgroup/$title",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "tune2fs -l /dev/$volgroup/$title | grep clean",
                        timeout => 3600,
                        require => Exec["lv-$volgroup/$title-size-$size"];
                    }
                    exec { "size-ext4-$volgroup/$title":
                        command => "/sbin/resize2fs -p /dev/$volgroup/$title",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/usr/bin/test \$[`(tune2fs -l /dev/$volgroup/$title | /bin/grep -i '^Block Count'|cut -b 27-)` * `(tune2fs -l /dev/$volgroup/$title | /bin/grep -i '^Block size'|cut -b 27-)` /1000000000 ] -ge $[`(lvs | grep $title | awk '{print \$4}' | cut -d . -f 1 )`]",
                        timeout => 3600,
                        require => Exec["mkfs.ext4-$volgroup/$title"];
                    }
                   exec { "ensure-ext4-$mountpoint":
                        command => "/bin/mkdir -p $mountpoint",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/ls $mountpoint",
                        require => Exec["size-ext4-$volgroup/$title"];
                   }
                    exec { "fstab-ext4-$volgroup/$title":
                        command => "/bin/echo '/dev/$volgroup/$title    $mountpoint                     $filesystem    defaults        1 2' >> /etc/fstab",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/cat /etc/fstab | /bin/grep $title && /bin/cat /etc/fstab | /bin/grep '$mountpoint '",
                        require => Exec["ensure-ext4-$mountpoint"];
                    }
                    exec { "mount-ext4-$volgroup/$title":
                        command => "/bin/mount -a ; rm -rf /$mountpoint/lost+found",
                        path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                        unless  => "/bin/mount | /bin/grep /dev/mapper/$volgroup-$title",
                        require => Exec["fstab-ext4-$volgroup/$title"];
                    }
              }
        }

            swap: {
                exec { "swap-$volgroup/$title-inactive":
                    command => "/sbin/swapoff /dev/$volgroup/$title",
                    path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                    unless  => "test \$[`(cat /proc/swaps | /bin/grep /dev/mapper/vg1-swap | /bin/awk '{print \$3}')` +8 ] -ge $size || test \$[`(cat /proc/swaps | /bin/grep /dev/dm-1 | /bin/awk '{print \$3}')` +8 ] -ge $size ",
                    onlyif  => "grep `/usr/bin/readlink /dev/$volgroup/$title` /proc/swaps",
                    require => Exec["lv-$volgroup/$title-size-$size"];
                }
                exec { "swap-$volgroup/$title":
                    command => "/sbin/mkswap /dev/$volgroup/$title",
                    path    => "/bin:/usr/bin:/sbin",
		    unless  => "test \$[`(cat /proc/swaps | /bin/grep /dev/mapper/vg1-swap | /bin/awk '{print \$3}')` +8 ] -ge $size || test \$[`(cat /proc/swaps | /bin/grep /dev/dm-1 | /bin/awk '{print \$3}')` +8 ] -ge $size ",
                    require => Exec["swap-$volgroup/$title-inactive"];
                }
                exec { "swap-$volgroup/$title-activate":
                    command => "/sbin/swapon /dev/$volgroup/$title",
                    path    => "/bin:/usr/bin:/sbin",
                    unless  => "test \$[`(cat /proc/swaps | /bin/grep /dev/mapper/vg1-swap | /bin/awk '{print \$3}')` +8 ] -ge $size || test \$[`(cat /proc/swaps | /bin/grep /dev/dm-1 | /bin/awk '{print \$3}')` +8 ] -ge $size ",
                    require => Exec["swap-$volgroup/$title"];
                }
            }
	    xfs: {
         	exec { "mkfs-xfs-$volgroup/$title":
                   command => "/sbin/mkfs.xfs -f /dev/$volgroup/$title",
                   path    => "/bin:/usr/bin:/sbin",
                   unless  => "/bin/df | /bin/grep $mountpoint",
                   require => [ Package["kmod-xfs"], Package["xfsprogs"], Exec["lv-$volgroup/$title-size-$size"]];
              	}
                exec { "ensure$mountpoint":
                   command => "/bin/mkdir -p $mountpoint",
                   path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                   unless  => "/bin/ls $mountpoint",
                   require => Exec["mkfs-xfs-$volgroup/$title"];
                }
                exec { "fstab-$volgroup/$title":
                   command => "/bin/echo '/dev/$volgroup/$title         $mountpoint                     $filesystem    defaults        1 2' >> /etc/fstab",
                   path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                   require => Exec["ensure$mountpoint"],
                   unless  => "/bin/cat /etc/fstab | /bin/grep $title && /bin/cat /etc/fstab | /bin/grep '$mountpoint '";
                }
                exec { "mount-$volgroup/$title":
                   command => "/bin/mount -a ; rm -rf /$mountpoint/lost+found",
                   path    => "/bin:/usr/bin:/usr/sbin:/sbin",
                   unless  => "/bin/mount | /bin/grep $mountpoint",
                   onlyif  => "cat /etc/fstab | /bin/grep $mountpoint",
                   require => Exec["fstab-$volgroup/$title"];
                }
         	exec { "XFS-$title":
                   command => "/usr/sbin/xfs_growfs $mountpoint",
                   path    => "/bin:/usr/bin:/usr/sbin:/sbin",
		   onlyif  => "/usr/bin/test \$[`(xfs_info /dev/drive_two/xfs-drive | /bin/grep data | /usr/bin/tail -1 | /bin/awk '{print \$4}' | /bin/sed s/blocks=//g | /bin/sed s/,//g)` * 4] -lt $size",
                   require => Exec["mount-$volgroup/$title"];
              	}
	    }
            raw: {
            }
              default: {
                exec { "/bin/echo Failed to create filesystem $filesystem on $volgroup/$title && /bin/false": }
            	}
        }
}
define disk_standard() {
    case $name {
        standard:  {
            disk_conf {
                "swap" :
                    mountpoint => "swap",
                    filesystem => "swap",
                    size       => "20971520",
                    prior      => "root";
                "root" :
                    mountpoint => "/",
                    size       => "-1";
            }
        }
    }
}
