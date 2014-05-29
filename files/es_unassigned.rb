#!/usr/bin/ruby

require 'rubygems'
require 'net/https'
require 'json'

# XXX poor error handling!!!
def json_get(url)
  uri = URI.parse(url)
  res = Net::HTTP.get_response(uri)
  JSON.parse(res.body)
end

state = json_get("http://localhost:9200/_cluster/state")
nodes = state['nodes']

indices = state["routing_table"]["indices"]
indices.each do |index|
  shards = index[1]["shards"]
  shards.each_pair do |number,data|
    data.each do |x|
      state = x["state"]
      next unless state == "UNASSIGNED"
      index = x["index"]
      node = x["node"]
      node_name = nodes[node]["name"]
      puts "found unassigned shard #{number} of index #{index} on node #{node_name}"
    end
  end
end

