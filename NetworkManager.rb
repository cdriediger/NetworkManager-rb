require 'sinatra'
require 'json'
require './NM-Database.rb'
require './Adapter/HPE_Aruba_Adapter.rb'
require './Models/Vlans.rb'

config = JSON.parse(File.read('./NetworkManager.conf'))
puts "ManagementVlan: #{config['ManagementVlan']}"
puts "ReadOnly Mode active. Won't change anything on Switches" if config['readonly']

switches = DB[:switches]
profiles = DB[:profiles]
vlans = DB[:vlans]
ports_profiles = DB[:ports_profiles]
switches_vlans = DB[:switches_vlans]

#switches.where(id: 1).delete()
#switches.where(id: 2).delete()
#switches.insert(ipv4: '192.168.1.50', name: 'EDV001S1', username: "manager", password: "I:nVm5I0")
#switches.insert(ipv4: '192.168.1.51', name: 'EDV001S2', username: "manager", password: "I:nVm5I0")
#adapter = HPE_Aruba_Adapter.new(switches.first[:ipv4], switches.first[:username], switches.first[:password])
#vlans = Vlans.new()
#vlans.parse_Aruba_response(adapter.getVlans())
#puts "VLANS: #{vlans}"
#adapter.close()

###################
## Switch ##
###################

get '/switches' do
    if params.has_key?(:ip)
        JSON.generate(switches.where(ipv4: params[:ip]).all)
    else
        JSON.generate(switches.all)
    end
end

get '/ui/home' do
    @switchList = switches.all
    @profileList = profiles.all
    
    @switchList.each do |switch|
        adapter = HPE_Aruba_Adapter.new(switch[:ipv4], switch[:username], switch[:password])
        switches_vlans.where(switchid: switch[:id]).delete()
        adapter.getVlans().each_pair do |vlanid, vlan|
            if vlans.where(vlanid: vlanid).count == 0
                vlans.insert(name: vlan[:name], vlanid: vlanid)
            end
            if switches_vlans.where(switchid: switch[:id]).where(vlanid: vlanid).count == 0
                switches_vlans.insert(switchid: switch[:id], vlanid: vlanid)
            end
        end
        adapter.close()
    end

    @vlanList = vlans.all
    erb :home
end

get '/ui/switches/create' do
    erb :new_switch
end

post '/ui/switches/create' do
    name = params[:name]
    ipv4 = params[:ipv4]
    location = params[:location]
    username = params[:username]
    password = params[:password]
    switches.insert(ipv4: ipv4, name: name, username: username, password: password)
    redirect '/ui/home'
end

get '/ui/switches/update/:id' do |id|
    switches.where(id: id).delete()
    redirect back
end

post '/ui/switches/updateport/:id' do |id|
    @switch = switches.where(id: id).first
    adapter = HPE_Aruba_Adapter.new(@switch[:ipv4], @switch[:username], @switch[:password])
    portid = params[:portid]
    description = params[:description]
    profilename = params[:profile]

    currentport = adapter.getPorts()[portid.to_s]
    currentdescription = currentport[:name]
    currentvlan = currentport[:untagged]
    currenttagged = currentport[:tagged]

    if profilename == " "
        if params[:vlan]
            vlanid = params[:vlan]
        else
            vlanid = currentvlan
        end
        begin
            newtagged = params[:tagged].split(',')
        rescue
            newtagged = currenttagged
        end
        addTaggedVlans = newtagged - currenttagged
        removeTaggedVlans = currenttagged - newtagged
        ports_profiles.where(switchid: id).where(portid: Integer(portid)).delete()

        puts "Update VLANs manualy:"
        puts "Params: #{params}"
        puts "Current VLAN: #{currentvlan}"
        puts "New VLAN: #{vlanid}"
        puts "Current Tagged: #{currenttagged}"
        puts "New Tagged: #{newtagged}"
        puts "Add Tagged: #{addTaggedVlans}"
        puts "Remove Tagged: #{removeTaggedVlans}"
    else
        profile = profiles.where(name: profilename).first

        vlanid = profile[:vlan]
        vlanid = config['ManagementVlan'] if vlanid == "0"
            
        if profile[:taggedVlans]
            if profile[:taggedVlans] == "*"
                if profile[:name] == "Uplink"
                    newtagged = adapter.getVlans().keys()
                    addTaggedVlans = newtagged - currenttagged
                    addTaggedVlans.delete(vlanid)
                    removeTaggedVlans = []
                elsif profile[:name] == "Downlink"
                    puts "Profile: Downlink"
                    remoteSwitchName = adapter.getPorts()[portid][:lldpSysName]
                    puts "remoteSwitchName: #{remoteSwitchName}"
                    remoteSwitch = switches.where(name: remoteSwitchName).first
                    puts "remoteSwitch: #{remoteSwitch}"
                    remoteAdapter = HPE_Aruba_Adapter.new(remoteSwitch[:ipv4], remoteSwitch[:username], remoteSwitch[:password])
                    newtagged = remoteAdapter.getVlans().keys()
                    addTaggedVlans = newtagged - currenttagged
                    addTaggedVlans.delete(vlanid)
                    removeTaggedVlans = []
                    remoteAdapter.close()
                end
            else
                newtagged = profile[:taggedVlans].split(',')
                addTaggedVlans = newtagged - currenttagged
                removeTaggedVlans = currenttagged - profile[:taggedVlans].split(',')
            end
        else
            newtagged = []
            addTaggedVlans = []
            removeTaggedVlans = []
        end
        ports_profiles.insert(switchid: id, portid: portid, profileid: profile[:id])

        puts "Update VLANs by Profile: #{profile[:name]}"
        puts "Params: #{params}"
        puts "Current VLAN: #{currentvlan}"
        puts "New VLAN: #{vlanid}"
        puts "Current Tagged: #{currenttagged}"
        puts "New Tagged: #{newtagged}"
        puts "Add Tagged: #{addTaggedVlans}"
        puts "Remove Tagged: #{removeTaggedVlans}"
    end
    if currentvlan != vlanid
        adapter.setPortVlan(portid, vlanid) unless config['readonly']
    end
    if currentdescription != description
        adapter.setPortDescription(portid, description) unless config['readonly']
    end
    removeTaggedVlans.each do |taggedvlanid|
        adapter.removePortTaggedVlan(portid, taggedvlanid) unless config['readonly']
    end
    addTaggedVlans.each do |taggedvlanid|
        adapter.addPortTaggedVlan(portid, taggedvlanid) unless config['readonly']
    end
    # Check if untagged VLAN was not overwriteen while tagging VLANs
    currentport = adapter.getPorts()[portid.to_s]
    currentvlan = currentport[:untagged]
    if currentvlan != vlanid
        adapter.setPortVlan(portid, vlanid) unless config['readonly']
    end
    adapter.close()
    redirect back
end

get '/ui/switches/delete/:id' do |id|
    switches.where(id: id).delete()
    redirect back
end

get '/switches/:id' do |id|
    JSON.generate(switches.where(id: id).all)
end

get '/ui/switches/:id' do |id|
    @switch = switches.where(id: id).first
    @profileList = profiles.all
    adapter = HPE_Aruba_Adapter.new(@switch[:ipv4], @switch[:username], @switch[:password])
    @ports = adapter.getPorts()
    @ports.each_pair do |portid, port|
        queryresult = ports_profiles.where(switchid: id).where(portid: portid).first
        if queryresult
            @ports[portid][:profileid] = queryresult[:profileid]
        end
    end
    puts "Port 1 tagged Vlans: #{@ports["1"][:tagged].to_json}"
    @vlans = adapter.getVlans()
    @allVlans = vlans.all()
    adapter.close()
    erb :switch
end

post '/switches' do
    ip = params[:ip]
    username = params[:username]
    password = params[:password]
    model = params[:model]
    name = params[:name]
    location = params[:location]
    switches.insert(ipv4: ip, name: name, username: username, password: password)
end

delete '/switches/:id' do |id|
    switches.where(id: id).delete()
end

###################
## VLANs ##
###################

get '/switches/:id/vlans' do |id|
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    vlans = adapter.getVlans()
    adapter.close()
    return vlans.to_json
end

get '/switches/:id/vlans/:vlanid' do |id, vlanid|
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    vlans = adapter.getVlans()
    adapter.close()
    return vlans[vlanid].to_json
end

post '/switches/:id/vlans' do |id|
    vlanid = params[:vlanid]
    name = params[:name]
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    adapter.createVlan(vlanid, name) unless config['readonly']
    vlans = adapter.getVlans()
    adapter.close()
    return vlans[vlanid].to_json
end

post '/ui/switches/:switchid/addvlan' do |switchid|
    vlanid = params[:addvlan]
    puts "Add VLAN #{vlanid} to Switch #{switchid}"
    sw = switches.where(id: switchid).first()
    vlan = vlans.where(vlanid: vlanid).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    adapter.createVlan(vlanid, vlan[:name]) unless config['readonly']
    adapter.close()
    redirect back
end

post '/ui/switches/:switchid/removevlan/:vlanid' do |switchid, vlanid|
    sw = switches.where(id: switchid).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    adapter.removeVlan(vlanid) unless config['readonly']
    adapter.close()
    redirect back
end

delete '/switches/:id/vlans/:vlanid' do |id, vlanid|
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    adapter.removeVlan(vlanid) unless config['readonly']
    adapter.close()
    return {}.to_json
end

get '/ui/vlans/:id' do |id|
    @vlan = vlans.where(id: id).first()
    @switchList = []
    puts "Getting Switches with VLAN ID: {id}"
    switches_vlans.select(:switchid).where(vlanid: @vlan[:vlanid]).all().each do |switchId|
        switchId = switchId[:switchid]
        puts "Vlan #{id} is on Switch #{switchId}"
        @switchList.append(switches.where(id: switchId).first())
    end

    erb :Vlan
end

get '/ui/vlans/create' do
    erb :new_vlan
end

post '/ui/vlans/create' do
    name = params[:name]
    vlanid = params[:vlanid]
    vlans.insert(name: name, vlanid: vlanid)
    redirect '/ui/home'
end

post '/ui/vlans/delete/:id' do |id|
    vlans.where(id: id).delete()
    redirect '/ui/home'
end

###################
## Ports ##
###################

get '/switches/:id/ports' do |id|
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    ports = adapter.getPorts()
    adapter.close()
    return ports.to_json
end

get '/switches/:id/ports/:portid' do |id, portid|
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    ports = adapter.getPorts()
    adapter.close()
    return ports[portid].to_json
end

post '/switches/:id/ports/:portid/vlan/:vlanid' do |id, portid, vlanid|
    sw = switches.where(id: id).first()
    adapter = HPE_Aruba_Adapter.new(sw[:ipv4], sw[:username], sw[:password])
    adapter.setPortVlan(portid, vlanid) unless config['readonly']
    ports = adapter.getPorts()
    adapter.close()
    return ports[portid].to_json
end

###################
## Profiles ##
###################

get '/profiles' do
    JSON.generate(profiles.all)
end

get '/profiles/:id' do |id|
    JSON.generate(profiles.where(id: id).all)
end

post '/profiles' do
    name = params[:name]
    vlan = params[:vlan]
    taggedVlans = params[:taggedVlans]    
    profiles.insert(name: name, vlan: vlan, taggedVlans: taggedVlans)
end

delete '/profiles/:id' do |id|
    profiles.where(id: id).delete()
end

get '/ui/profiles/create' do
    erb :new_profile
end

post '/ui/profiles/create' do
    name = params[:name]
    vlan = params[:vlan]
    taggedVlans = params[:taggedVlans]
    profiles.insert(name: name, vlan: vlan, taggedVlans: taggedVlans)
    redirect '/ui/home'
end

get '/ui/profiles/delete/:id' do |id|
    profiles.where(id: id).delete()
    redirect back
end