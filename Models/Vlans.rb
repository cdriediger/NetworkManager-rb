class Vlans < Hash

    # Struktur: {"1":{"name":"DEFAULT_VLAN","untagged":["8","9"],"tagged":[]},"2":{"name":"TestNetz","untagged":[],"tagged":["49","50","51","52"]}
    def initialize()

    end

    def parse_Aruba_response(vlans, vlansPorts)
        puts "Got '#{vlans.class}' & '#{vlansPorts['vlan_port_element'].class}'"
        vlans['vlan_element'].each do |vlan|
            self[vlan['vlan_id'].to_s] = {name: vlan['name'], untagged: [], tagged: []}
        end
        vlansPorts['vlan_port_element'].each do |vlanPort|
            if vlanPort['port_mode'] == "POM_UNTAGGED"
                self[vlanPort['vlan_id'].to_s][:untagged].append(vlanPort['port_id'])
            elsif vlanPort['port_mode'] == "POM_TAGGED_STATIC"
                self[vlanPort['vlan_id'].to_s][:tagged].append(vlanPort['port_id'])
            end
        end
    end

end

