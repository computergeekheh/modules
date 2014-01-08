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
}

