#!/usr/bin/ruby1.9.1
require 'eventmachine'
require './hpfeedshandler.rb'

def mysleep(n)
	f = Fiber.current
	EventMachine::Timer.new(n) do f.resume end
	Fiber.yield
end

class HPFeed
	def initialize(server, port, ident, auth, payload_handler)
		@feed = EventMachine::connect(server, port, HPFeedHandler, ident, auth, payload_handler)
		@feed.connect
		mysleep(1)
	end

	def subscribe(chan)
		@feed.subscribe(chan)
	end
end
