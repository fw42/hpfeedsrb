#!/usr/bin/env ruby
require 'digest/sha1'
require 'fiber'

class HPFeed
	def initialize(server, port, *args)
		@feed = EventMachine::connect(server, port, HPFeedConnection, *args)
		@connected = Fiber.yield
		# Fix for stupid bug in old version of feed server
		mysleep(1)
	end

	def connected?
		@connected
	end

	def subscribe(*args)
		@feed.subscribe(*args)
	end

	private
	def mysleep(n)
		f = Fiber.current
		EventMachine::Timer.new(n) do f.resume end
		Fiber.yield
	end
end

module HPFeedConnection
	OP = { error: 0, info: 1, auth: 2, publish: 3, subscribe: 4 }

	public

	def initialize(ident, auth, error_handler=nil)
		@ident, @auth = ident, auth
		@f = Fiber.current
		@buf = ""
		@handler = {}
		@error_handler = error_handler
	end

	def subscribe(chan, payload_handler)
		@handler[chan] = payload_handler
		send(msg_sub(@ident, chan))
	end

	######

	def receive_data(data)
		@buf << data
		while @buf.length > 5
			len = @buf[0,4].unpack("l>")[0]
			op = @buf[4,1].unpack("C")[0]
			break if @buf.length < len
			data = @buf[5,(len-5)]
			@buf = @buf[len..-1] || ""
			parse(op, data)
		end
	end

	def unbind
		if @f.alive?
			@f.resume(false)
		end
	end

	def connection_completed
		@peer = Socket.unpack_sockaddr_in(get_peername)
		puts "Connected to #{@peer[1]}:#{@peer[0]}"
	end

	######

	private

	def send(data)
		send_data(data)
	end

	def parse(op, data)
		if op == OP[:info]
			len = data[0,1].unpack("C")[0]
			name = data[1,len]
			rand = data[(1+len)..-1]
			send(msg_auth(rand, @ident, @auth))
			@f.resume(true)
		elsif op == OP[:publish]
			len = data[0,1].unpack("C")[0]
			name = data[1,len]
			len2 = data[(1+len),1].ord
			chan = data[(1+len+1),len2]
			payload = data[(1+len+1+len2)..-1]
			@handler[chan].call(name, chan, payload) if @handler[chan]
		elsif op == OP[:error]
			@error_handler.call(data) if @error_handler
		else
			# Unknown opcode
		end
	end

	######

	private

	def msg_hdr(op, data)
		[5+data.length].pack("l>") + [op].pack("C") + data
	end

	def msg_sub(ident, chan)
		msg_hdr(OP[:subscribe], [ident.length].pack("C") + ident + chan)
	end

	def msg_auth(rand, ident, secret)
		mac = Digest::SHA1.digest(rand + secret) # TODO: use HMAC
		msg_hdr(OP[:auth], [ident.length].pack("C") + ident + mac)
	end

end
