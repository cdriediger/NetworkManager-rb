class Ports < Hash

    # Struktur: {"1":{"name":"PORT-NAME","enabled":"true","up":"true", untagged: 1, tagged: [2,3], profileid: nil, lldpSysName: "SystemName", lldpMacAddress: "AA:BB:CC:DD:EE:FF"},
    #            "2":{"name":"Port-Name2","enabled":"true","up":"false", untagged: 2, tagged: [], profileid: 2, lldpSysName: "", lldpMacAddress: ""}
    def initialize()

    end

    def parse_Aruba_response(ports, vlansPorts, lldpRemoteDevices)
        puts "Got '#{ports.class}' & '#{vlansPorts['vlan_port_element'].class}'"
        ports['port_element'].each do |port|
            self[port['id'].to_s] = {name: port['name'], enabled: port['is_port_enabled'], up: port['is_port_up'], untagged: "", tagged: [], profileid: nil}
        end
        vlansPorts['vlan_port_element'].each do |vlanPort|
            if vlanPort['port_mode'] == "POM_UNTAGGED"
                self[vlanPort['port_id'].to_s][:untagged] = vlanPort['vlan_id'].to_s
            elsif vlanPort['port_mode'] == "POM_TAGGED_STATIC"
                self[vlanPort['port_id'].to_s][:tagged].append(vlanPort['vlan_id'].to_s)
            end
        end
        lldpRemoteDevices['lldp_remote_device_element'].each do |remoteDevice|
            self[remoteDevice['local_port'].to_s][:lldpSysName] = remoteDevice['system_name'].to_s
            self[remoteDevice['local_port'].to_s][:lldpMacAddress] = remoteDevice['chassis_id'].to_s
        end
    end

    def map_profiles(ports_profiles)

    end

end