#!/usr/bin/env ruby
require 'eventmachine'
require 'json'
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

begin
	EventMachine::run do
		Fiber.new{
			hp = HPFeed.new(
				$config[:server],
				$config[:port],
				$config[:ident],
				$config[:auth],
			)
			hp.subscribe("geoloc.events", method(:handle_payload))
		}.resume
	end
rescue Interrupt
end
