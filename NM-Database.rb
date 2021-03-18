require 'Sequel'

DB = Sequel.sqlite('.\NetworkManager.db')

#DB.drop_table(:switches)
#DB.create_table :switches do
#    primary_key :id
#    String :ipv4
#    String :username
#    String :password
#    String :adaptername
#    String :name
#    String :location
#    String :modelName
#    String :lastUpdate
#end

#DB.drop_table(:profiles)
#DB.create_table :profiles do
#    primary_key :id
#    String :name
#    String :vlan
#    String :taggedVlans
#end
#DB[:profiles].insert(name: "Uplink", vlan: "0", taggedVlans: "*")
#DB[:profiles].insert(name: "Downlink", vlan: "0", taggedVlans: "*")

#DB.drop_table(:vlans)
#DB.create_table :vlans do
#    primary_key :id
#    String :name
#    String :vlanid
#end

#DB.drop_table(:ports_profiles)
#DB.create_table :ports_profiles do
#    primary_key :id
#    Int :switchid
#    Int :portid
#    Int :profileid
#end

#DB.drop_table(:switches_vlans)
#DB.create_table :switches_vlans do
#    primary_key :id
#    Int :switchid
#    Int :vlanid
#end