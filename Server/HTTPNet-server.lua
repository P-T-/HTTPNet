------------------------------------------------
--  HTTPNet server
--  By PixelToast
--
--  Requires lua 5.1 with luasocket.
--
--  TODO:
--    DOS protection
--    comments
--    moar config options
--    error checking
--    clean up a bit
--    add a reconnect buffer so messages arent lost in the short time the client is offline
------------------------------------------------

------------------------------------------------
--  Config
------------------------------------------------

local config={
	port=1337,
}

------------------------------------------------
-- Server
------------------------------------------------

local socket=require "socket"
local sv=socket.bind("*",config.port)
sv:settimeout(0)
local cli={}
local function getmax(tbl)
	local mx=0
	for k,v in pairs(tbl) do
		if type(k)=="number" and v then
			if k>mx then
				mx=k
			end
		end
	end
	return mx
end
local function genuid()
	local o=""
	for l1=1,16 do
		o=o..string.format("%X",math.random(1,15))
	end
	return o
end
local function serialize(...)
	local t={...}
	local out=""
	for k,v in pairs(t) do
		v=tostring(v)
		for c in v:gmatch(".") do
			if c=="\\" then
				out=out.."\\\\"
			elseif c=="," then
				out=out.."\\,"
			else
				out=out..c
			end
		end
		if k~=#t then
			out=out..","
		end
	end
	return out
end
local function unserialize(t)
	local elevel=0
	local out={}
	local s=""
	for char in t:gmatch(".") do
		if char=="\\" then
			if clevel==0 then
				clevel=1
			else
				s=s.."\\"
				clevel=0
			end
		elseif char=="," then
			if clevel==0 then
				table.insert(out,s)
				s=""
			else
				s=s..","
				clevel=0
			end
		else
			s=s..char
			clevel=0
		end
	end
	table.insert(out,s)
	return out
end
local function prochead(cl)
	local head={}
	local t
	for k,v in pairs(cl.head) do
		t=string.find(v," ")
		if t then
			head[string.sub(v,1,t-1)]=string.sub(v,t+1)
		end
	end
	return head
end
local queue={}
local function close(cl)
	cl.s:close()
	cl.closed=true
	queue[cl.i]=nil
	cli[cl.i]=nil
end
local function serve(cl,dat)
	cl.s:send("HTTP/1.1 337 H4X\r\nContent-Length: "..dat:len().."\r\n\r\n"..dat) -- nothing to see here
	close(cl)
end
local function req(cl,s)
	local t=unserialize(s)
	if cl.postlen and not t then
		close(cl)
	else
		if cl.uri=="ping" then
			serve(cl,serialize("pong",genuid()))
		elseif cl.uri=="send" and t[3] then
			print("'"..serialize(t[1]).."' is sending '"..serialize(t[3]).."' to '"..serialize(t[2]).."'")
			for k,v in pairs(queue) do
				if v.id==t[2] then
					serve(v,serialize(v.uid,"msg",t[1],t[3]))
					queue[k]=nil
				end
			end
			serve(cl,"")
		elseif cl.uri=="receive" and t[1] then
			if not cl.uid then
				print("Bad request "..cl.id)
			else
				print("'"..serialize(t[1]).."' is receiving")
				cl.id=t[1]
				table.insert(queue,cl)
			end
		else
			close(cl)
		end
	end
end
local ltime=os.clock()
while true do
	local s=sv:accept()
	while s do
		s:settimeout(0)
		local a=1
		while true do
			if not cli[a] then
				cli[a]={s=s,head={},i=a,dt=0}
				break
			end
			a=a+1
		end
		s=sv:accept()
	end
	local cdt=os.clock()-ltime
	for i=1,getmax(cli) do
		local cl=cli[i]
		if cl then
			cl.dt=cl.dt+cdt
			if cl.dt>30 then
				for k,v in pairs(queue) do
					if v then
						if v.s==cl then
							queue[k]=nil
						end
					end
				end
				print("'"..cl.id.."' timed out")
				serve(cl,serialize(cl.uid,"timeout"))
			end
			local s,e=cl.s:receive(0)
			if e=="closed" and not s then
				close(cl)
			else
				local s,e=cl.s:receive(cl.postlen)
				while s do
					if cl.postlen then
						req(cl,s)
					elseif s=="" then
						local pg,d=cl.head[1]:match("^(.-) (.-) HTTP/1.1$")
						if not cl.postlen then
							cl.uri=d:sub(2):gsub("(%?(.+))$","")
							cl.uid=d:sub(2):match("%?(.+)$")
							cl.rid=d
							if pg=="POST" then
								cl.postlen=tonumber(prochead(cl)["Content-Length:"])
							else
								req(cl,s)
							end
						else
							close(cl)
						end
					else
						table.insert(cl.head,s)
					end
					if not cl.closed then
						s,e=cl.s:receive(cl.postlen)
					else
						s=nil
					end
				end
			end
		end
	end
	ltime=os.clock()
	local clt={sv}
	for k,v in pairs(cli) do
		table.insert(clt,v.s)
	end
	socket.select(clt,nil,10)
end
