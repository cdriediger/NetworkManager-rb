require 'rest-client'
require './Models/Vlans.rb'
require './Models/Ports.rb'

class HPE_Aruba_Adapter

    def initialize(ip, username, password)
        @api = ArubaApiHelper.new(ip, username, password)
        @connected = @api.connect()
    end

    def close()
        @api.close()
    end

    # Vlans
    
    def getVlans()
        vlans = @api.query("/rest/v6/vlans")
        vlansPorts = @api.query("/rest/v6/vlans-ports")
        result = Vlans.new()
        result.parse_Aruba_response(vlans, vlansPorts)
        return result
    end

    def createVlan(vlanid, name)
        @api.post('/rest/v6/vlans', {"vlan_id": Integer(vlanid), "name": name})
    end

    def removeVlan(vlanid)
        @api.delete("/rest/v6/vlans/#{vlanid}")
    end

    # Ports

    def getPorts()
        ports = @api.query("/rest/v6/ports")
        vlansPorts = @api.query("/rest/v6/vlans-ports")
        lldpRemoteDevices = @api.query("/rest/v6/lldp/remote-device")
        result = Ports.new()
        result.parse_Aruba_response(ports, vlansPorts, lldpRemoteDevices)
        return result
    end

    def setPortDescription(portid, description)
        url = "/rest/v6/ports/#{portid}"
        portconfig = @api.query(url)
        portconfig["name"] = description
        puts "Portconfig:"
        puts portconfig
        puts "####################"
        @api.put("/rest/v6/ports/#{portid}", portconfig)
    end

    def setPortVlan(portid, vlanid)
        @api.post("/rest/v6/vlans-ports", {"vlan_id": Integer(vlanid), "port_id": portid.to_s, "port_mode": "POM_UNTAGGED"})
    end

    def addPortTaggedVlan(portid, vlanid)
        portconfig = {"vlan_id": Integer(vlanid), "port_id": portid.to_s, "port_mode": "POM_TAGGED_STATIC"}
        @api.post("/rest/v6/vlans-ports", portconfig)
    end

    def removePortTaggedVlan(portid, vlanid)
        @api.delete("/rest/v6/vlans-ports/#{vlanid}-#{portid}")
    end

end

class ArubaApiHelper

    def initialize(ip, username, password)
        @ip = ip
        @username = username
        @password = password
        @connected = false
        @cookie = nil
    end

    def connect()
        url = "http://#{@ip}/rest/v6/login-sessions"
        params = {"userName":@username, "password":@password}.to_json
        #puts "Post: URL: #{url} Params: #{params}"
        response = RestClient.post(url, params, {content_type: :json, accept: :json})
        @cookie =  JSON.parse(response)['cookie'].split('=')[1]
        puts "Response from login: #{response}"
        puts "Cookie: #{@cookie}"
        return true
    end

    def close()
        url = "http://#{@ip}/rest/v6/login-sessions"
        #header = {cookies: {sessionId: @cookie}}
        header = {:cookies => {:sessionId => @cookie}}
        response = RestClient.delete(url, header)
        puts "Response from logout: #{response}"
    end

    def query(url)
        url = "http://#{@ip}#{url}"
        #header = {cookies: {sessionId: @cookie}}
        header = {:cookies => {:sessionId => @cookie}}
        puts "Query: GET #{url} Header #{header}"
        response = RestClient.get(url, header)
        #puts "Response from Query #{response}"
        return JSON.parse(response)
    end

    def post(url, params) # params example: {"vlan_id": 5, "name": "VLAN5"}
        url = "http://#{@ip}#{url}"
        #header = {content_type: 'application/json', cookies: {sessionId: @cookie}}
        header = {content_type: 'application/json', :cookies => {:sessionId => @cookie}}
        puts "Post: URL: #{url} Params: #{params} Header: #{header}"
        response = RestClient.post(url, params.to_json, header)
        #puts "Response from Post #{response}"
        return JSON.parse(response)
    end

    def put(url, params) # params example: {"vlan_id": 5, "name": "VLAN5"}
        url = "http://#{@ip}#{url}"
        #header = {content_type: 'application/json', cookies: {sessionId: @cookie}}
        header = {content_type: 'application/json', :cookies => {:sessionId => @cookie}}
        puts "Put: URL: #{url} Params: #{params} Header: #{header}"
        response = RestClient.put(url, params.to_json, header)
        #puts "Response from Post #{response}"
        return JSON.parse(response)
    end

    def delete(url)
        url = "http://#{@ip}#{url}"
        #header = {cookies: {sessionId: @cookie}}
        header = {:cookies => {:sessionId => @cookie}}
        puts "Delete: URL: #{url}  Header: #{header}"
        response = RestClient.delete(url, header)
        #puts "Response from Delete #{response}"
        return true
    end
end