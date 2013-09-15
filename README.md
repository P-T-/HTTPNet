![ScreenShot](http://i.imgur.com/Pd6fcpa.png)

A ComputerCraft API that allows instant socket like connections using HTTP<br>
Communication over HTTP has been done before, but this one does not spam yet is still instant<br>
This is possible because the http events will not fire until the socket is closed or the data has been sent<br>

forum thread: http://www.computercraft.info/forums2/index.php?/topic/15226-httpnet-development/

Documentation
=======

Events
-------

<code>httpnet\_message sender\_id message</code>

Functions
-------

<code>httpnet.setHost([host],[port],[id])</code><br>
host defaults to "localhost"<br>
port defaults to 1337<br>
and id defaults to os.getComputerID()<br>
the id can be a string!<br><br>


<code>httpnet.get([timeout])</code><br>
will wait for the httpnet_message and returns id,message<br><br>


<code>httpnet.send(id,data)</code><br>
sends a message, stupid<br><br>


<code>httpnet.close()</code><br>
prevents you from sending or receiving<br>
warning: this will currently leak a http_sucess when it times out (when timeouts are implemented)<br><br>
