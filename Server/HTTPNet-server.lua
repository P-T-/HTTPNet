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
--    timeouts
--    clean up a bit
--    "salt" collision detection
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
	return "httpnet,"..out
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
	if out[1]=="httpnet" then
		table.remove(out,1)
		return out
	else
		return {}
	end
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
	queue[cl.id]=nil
	cli[cl.i]=nil
end
local function serve(cl,dat)
	cl.s:send("HTTP/1.1 337 Potato\r\nContent-Length: "..dat:len().."\r\n\r\n"..dat)
	close(cl)
end
while true do
	local s=sv:accept()
	while s do
		s:settimeout(0)
		local a=1
		while true do
			if not cli[a] then
				cli[a]={s=s,head={},i=a}
				break
			end
			a=a+1
		end
		s=sv:accept()
	end
	for i=1,getmax(cli) do
		local cl=cli[i]
		if cl then
			local s,e=cl.s:receive(0)
			if e=="closed" and not s then
				cl.s:close()
				cli[i]=nil
			else
				local s,e=cl.s:receive(cl.postlen)
				while s do
					print(s)
					if cl.postlen then
						local t=unserialize(s)
						if not t then
							close(cl)
						else
							if cl.uri=="send" and t[4] then
								for k,v in pairs(queue) do
									if v.id==t[3] then
										serve(v,serialize("rec",v.sl,t[2],t[4]))
									end
								end
								serve(cl,"snd",t[1])
							elseif cl.uri=="receive" and t[2] then
								if queue[t[1]] then
									close(queue[t[1]])
								end
								cl.id=t[2]
								cl.sl=t[1]
								queue[t[1]]=cl
							elseif cl.uri=="mreceive" then
								if table.maxn(t)%2==0 then
									local r
									local s=t[1]
									table.remove(t,1)
									for k,v in pairs(t) do
										if not queue[v] then
											r=v
											break
										end
									end
									serve(cl,serialize("mcr",s,r))
								else
									close(cl)
								end
							else
								close(cl)
							end
						end
					elseif s=="" then
						local pg,d=cl.head[1]:match("^(.-) (.-) HTTP/1.1$")
						if pg=="POST" and not cl.postlen then
							cl.uri=d:sub(2)
							cl.postlen=tonumber(prochead(cl)["Content-Length:"])
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
	local clt={sv}
	for k,v in pairs(cli) do
		table.insert(clt,v.s)
	end
	socket.select(clt,nil)
end
