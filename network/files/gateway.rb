Facter.add(:gateway) do
    setcode do
        ip = nil
        output = %x{netstat -rn|awk '{print $8,$2}'|grep -v 0.0.0.0|grep -v Gateway|grep -v IP}

        output.split(/^\S/).each { |str|
            if str =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/
                tmp = $1
                unless tmp =~ /^127\./
                    ip = tmp
                    break
                end
            end
        }

        ip
    end
end

