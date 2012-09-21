#!/usr/bin/ruby1.9.1
require 'digest/sha1'
require 'fiber'

module HPFeedHandler

	OP = { error: 0, info: 1, auth: 2, publish: 3, subscribe: 4 }

	def initialize(ident, auth, payload_handler)
		@payload_handler = payload_handler
		@ident, @auth = ident, auth
		@f = Fiber.current
		@ready = false
		@buf = ""
	end

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

	######

	def connect
		Fiber.yield
	end

	def subscribe(chan)
		send(msg_sub(@ident, chan))
	end

	def send(data)
		send_data(data)
	end

	def parse(op, data)
		if op == OP[:info]
			len = data[0,1].unpack("C")[0]
			name = data[1,len]
			rand = data[(1+len)..-1]
			send(msg_auth(rand, @ident, @auth))
			@ready = true
			@f.resume
		elsif op == OP[:publish]
			len = data[0,1].unpack("C")[0]
			name = data[1,len]
			len2 = data[(1+len),1].ord
			chan = data[(1+len+1),len2]
			payload = data[(1+len+1+len2)..-1]
			@payload_handler.call(name, chan, payload) if @payload_handler
		elsif op == OP[:error]
			STDERR.puts "ERROR: " + [op, data].inspect
		else
			STDERR.puts "ERROR: Unknown opcode (#{op.inspect})"
		end
	end

	######

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
