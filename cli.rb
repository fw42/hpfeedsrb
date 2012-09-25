#!/usr/bin/env ruby
require 'eventmachine'
require 'json'
require 'fiber'
require 'wirble'
require './hpfeeds.rb'
require './config.rb'

def on_data(name, chan, payload)
	begin
		json = JSON.parse(payload)
		puts "[%s] %s: %s" % [ chan, name, Wirble::Colorize.colorize(json.inspect) ]
	rescue JSON::ParserError
		STDERR.puts "ERROR: JSON Parse Error"
	end
end

def on_error(data)
	STDERR.puts "ERROR: " + data.inspect
end

begin
	EventMachine::run do
		Fiber.new{
			hp = HPFeed.new(
				$config[:server],
				$config[:port],
				$config[:ident],
				$config[:auth],
				method(:on_error)
			)
			if hp.connected?
				hp.subscribe("geoloc.events", method(:on_data))
			else
				EventMachine::stop
			end
		}.resume
	end
rescue Interrupt
end
