require 'facter'
Facter.add("virsh_uuid") do
  setcode do
    %x{/usr/bin/virsh secret-list | /bin/grep Unused | awk '\{print $1\}'}
  end
end

