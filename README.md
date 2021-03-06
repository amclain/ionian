# Ionian

[![Gem Version](https://badge.fury.io/rb/ionian.png)](http://badge.fury.io/rb/ionian)


A Ruby library to simplify interaction with IO streams. This includes network sockets, file sockets, and serial streams like the console and RS232. Features regular expression matching and notification of received data.


## Supported Ruby Versions

- MRI >= 2.0.0


## Installation

	gem install ionian


## Issues, Bugs, Feature Requests

Any bugs and feature requests should be reported on the GitHub issue tracker:

https://github.com/amclain/ionian/issues


**Pull requests are preferred via GitHub.**

Mercurial users can use [Hg-Git](http://hg-git.github.io/) to interact with
GitHub repositories.


## Code Examples

### Creating A Socket

``` ruby
socket = Ionian::Socket.new host: '127.0.0.1', port: 23
```

### Sending And Receiving Data

``` ruby
socket = Ionian::Socket.new host: 'google.com', port: 80
socket.write "GET / HTTP/1.1\r\n\r\n"
socket.read_match { |match| p match; puts '' }
```

### Match Expressions And Named Captures

``` ruby
# A simple IRC client.

socket = Ionian::Socket.new \
  host: 'chat.freenode.net:6667',
  # Break up the matches into named captures so it's easier
  # to sort through the server's responses.
  expression: /:(?<server>.*?)\s*:(?<msg>.*?)[\r\n]+/

# Log on to IRC and send a message.
socket.write "NICK ionian-demo\r\nUSER ionian-demo ionian-demo chat.freenode.net :ionian-demo"
socket.write "PROTOCL NAMESX\r\n"
socket.write "JOIN #ionian-demo\r\n"
socket.write "PRIVMSG #ionian-demo :this is a test\r\n"


loop do
  socket.read_match do |match|
  	# Print the body of the server's responses.
    puts match.msg
    
    # Exit when the server has caught up.
    exit if match.msg.include? 'End of /NAMES list.'
  end
end
```

### Simple Server

``` ruby
host = 'localhost:5000'

server = Ionian::Server.new interface: host do |client|
  # Greet the connected client.
  client.write "Welcome! You are connected to the server.\n"
end

socket = Ionian::Socket.new host: host
# Retrieve the greeting message.
puts socket.read_all
```
