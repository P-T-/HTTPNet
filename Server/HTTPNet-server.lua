------------------------------------------------
--  HTTPNet server
--  By PixelToast
--
--  Requires lua 5.1 with luasocket.
------------------------------------------------

------------------------------------------------
--  Config
------------------------------------------------

local config={
	port=1337,
	rainbow=false, -- ANSI colors dont work on windows :/
}

------------------------------------------------
-- Server
------------------------------------------------

local print=print
if config.rainbow then
	local oprint=print
	function print(str)
		oprint(str:gsub(".",function(s) local r=math.random(0,5) return "\27["..(r+31).."m\27["..(((r+math.random(1,5))%6)+41).."m"..s end).."\27[0m")
	end
end 
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
	local i
	for l1=1,16 do
		i=math.random(0,15)
		o=o..string.char(i+(math.floor(i/10)*7)+48)
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
		if cl.uid and (cl.uri=="open" or cl.uri=="close") then
			local c=queue[cl.uri]
			if c then
				if t[1] then
					local l=cl.uri=="open" or nil
					if l then
						print(cl.uid.." opening "..table.concat(t,","))
					else
						print(cl.uid.." closing "..table.concat(t,","))
					end
					for k,v in pairs(t) do
						c.chan[v]=l
					end
					if not next(c.chan) then
						serve(c,serialize(c.uid))
						queue[cl.uri]=nil
					end
				else
					print(cl.uid.." closing all")
					for k,v in pairs(c.chan) do
						c.chan[k]=nil
					end
					serve(c,serialize(c.uid))
					queue[cl.uri]=nil
				end
			end
			serve(cl,serialize(cl.uid))
		end
		if cl.uid and cl.uri=="exit" then
			print(cl.uid.." is exiting")
			local c=queue[cl.uid]
			if c then
				serve(c,"")
				queue[cl.uid]=nil
			end
			serve(cl,serialize(cl.uid,"exit"))
		elseif cl.uri=="ping" then
			print("new client")
			serve(cl,serialize("pong",genuid()))
		elseif cl.uri=="send" and t[3] then
			print("'"..serialize(t[2]).."' is sending '"..serialize(t[3]).."' to '"..serialize(t[1]).."'")
			for k,v in pairs(queue) do
				if v.chan[t[1]] then
					serve(v,serialize(v.uid,"msg",t[1],t[2],t[3]))
					queue[k]=nil
				end
			end
			serve(cl,"")
		elseif cl.uri=="receive" and t[1] then
			if not cl.uid then
				print("bad request "..cl.uid)
			else
				print(cl.uid.." is receiving")
				for k,v in pairs(t) do
					cl.chan[v]=true
				end
				queue[cl.uid]=cl
			end
		else
			close(cl)
		end
	end
end
local ltime=os.time()
print("Server running on port "..config.port)
while true do
	local s=sv:accept()
	while s do
		s:settimeout(0)
		local a=1
		while true do
			if not cli[a] then
				cli[a]={s=s,head={},i=a,dt=0,chan={}}
				break
			end
			a=a+1
		end
		s=sv:accept()
	end
	local cdt=os.time()-ltime
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
				print(cl.uid.." timed out")
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
	ltime=os.time()
	local clt={sv}
	for k,v in pairs(cli) do
		table.insert(clt,v.s)
	end
	socket.select(clt,nil,10)
end
