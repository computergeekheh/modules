

class ceph {

        package { ['ceph-deploy', 'ceph']: ensure  => latest; }


}
