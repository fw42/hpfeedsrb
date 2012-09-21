#!/usr/bin/ruby1.9.1
require 'eventmachine'
require 'json'
require 'pp'
require 'fiber'
require 'wirble'
require './hpfeeds.rb'
require './config.rb'

def handle_payload(name, chan, payload)
	begin
		json = JSON.parse(payload)
		puts "[%s] %s: %s" % [ chan, name, Wirble::Colorize.colorize(json.inspect) ]
	rescue JSON::ParserError
		STDERR.puts "ERROR: JSON Parse Error"
	end
end

EventMachine::run do
	Fiber.new{
		hp = HPFeed.new($config[:server], $config[:port], $config[:ident], $config[:auth], method(:handle_payload))
		hp.subscribe("geoloc.events")
	}.resume
end
