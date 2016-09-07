require 'httprecognizer/constants'
require 'httprecognizer/version'
require 'deque'

# Parent expected to provide following API:
#
# default_name
# known_name?
# keepalive?
# now
# logger
# add_client
# remove_client
#
# This module implements the HTTP handling code. I call it a recognizer,
# and not a parser because it does not parse HTTP. It is much simpler than
# that, being designed only to recognize certain useful bits very quickly.

class HttpRecognizer
  class NotImplemented < Exception; end
  class Http400Error < Exception; end
  class Http404Error < Exception; end

  attr_accessor :create_time, :last_action_time, :uri, :unparsed_uri, :associate, :name, :redeployable, :data_pos, :data_len, :peer_ip, :connection_header, :keepalive, :header_data

  # Initialize the @data array, which is the temporary storage for blocks
  # of data received from the web browser client, then invoke the superclass
  # initialization.

  def initialize webserver=nil
    @data = Deque.new
    @data_pos = 0
    @connection_header = C_empty
    @header_missing_pieces = @name = @uri = @unparsed_uri = @http_version = @request_method = @none_match = @done_parsing = @header_data = nil
    @keepalive = true
    @webserver = webserver
  end

  def done_parsing?
    @done_parsing
  end

  def reset_state
    @data.clear
    @data_pos = 0
    @connection_header = C_empty
    @header_missing_pieces = @name = @uri = @unparsed_uri = @http_version = @request_method = @none_match = @done_parsing = @header_data = nil
    @keepalive = true
  end
      
  # States:
  # uri
  # name
  # \r\n\r\n
  #   If-None-Match
  # Done Parsing
  def receive_data data
    if @done_parsing
      @data.unshift data
      push
    else
      if @header_missing_pieces
        # Hopefully this doesn't happen often.
        d = @data.to_s << data
        @header_missing_pieces = false
      else
        d = data
      end
      unless @uri
        # It's amazing how, when writing the code, the brain can be in a zone
        # where line noise like this regexp makes perfect sense, and is clear
        # as day; one looks at it and it reads like a sentence.  Then, one
        # comes back to it later, and looks at it when the brain is in a
        # different zone, and 'lo!  It looks like line noise again.
        #
        # data =~ /^(\w+) +(?:\w+:\/\/([^\/]+))?([^ \?]+)\S* +HTTP\/(\d\.\d)/
        #
        # In case it looks like line noise to you, dear reader, too:            
        #
        # 1) Match and save the first set of word characters.
        #
        #    Followed by one or more spaces.
        #
        #    Match but do not save the word characters followed by ://
        #
        #    2) Match and save one or more characters that are not a slash
        #
        #    And allow this whole thing to match 1 or 0 times.
        #
        # 3) Match and save one or more characters that are not a question
        #    mark or a space.
        #
        #    Match zero or more non-whitespace characters, followed by one
        #    or more spaces, followed by "HTTP/".
        #
        # 4) Match and save a digit dot digit.
        #
        # Thus, this pattern will match both the standard:
        #   GET /bar HTTP/1.1
        # style request, as well as the valid (for a proxy) but less common:
        #   GET http://foo/bar HTTP/1.0
        #
        # If the match fails, then this is a bad request, and an appropriate
        # response will be returned.
        #
        # http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec5.1.2
        #
        if d =~ /^(\w+) +(?:\w+:\/\/([^ \/]+))?(([^ \?\#]*)\S*) +HTTP\/(\d\.\d)/
          @request_method = $1
          @unparsed_uri = $3
          @uri = $4
          @http_version = $5
          if $2
            @name = $2.intern
            @uri = C_slash if @uri.empty?
            # Rewrite the request to get rid of the http://foo portion.
            
            d.sub!(/^\w+ +\w+:\/\/[^ \/]+([^ \?]*)/,"#{@request_method} #{@uri}")
          end
          @uri = @uri.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) {[$1.delete(C_percent)].pack('H*')} if @uri.include?(C_percent)
        elsif d.include?(Crn)
          raise Http400Error
          return
        end
      end
      unless @name
        if d =~ /^Host:\s*([^\r\0:]+)\r?\n/m
          @name = $1.intern
        end
      end
      if d.include?(Crnrn)
        @name = ( @webserver.respond_to?(:default_name) && @webserver.respond_to?(:known_name?) ) ?
          ( @webserver.known_name?(@name) ? @name : @webserver.default_name ) :
          @name
        if d =~ /If-None-Match: *([^\r]+)/
          @none_match = $1
        end
        @header_data = d.scan(/Cookie:.*/).collect {|c| c =~ /: ([^\r]*)/; $1}
        @done_parsing = true

        # Keep-Alive works differently on HTTP 1.0 versus HTTP 1.1
        # HTTP 1.0 was not written to support Keep-Alive initially; it was
        # bolted on.  Thus, for an HTTP 1.0 client to indicate that it
        # wants to initiate a Keep-Alive session, it must send a header:
        #
        # Connection: Keep-Alive
        #
        # Then, when the server sends the response, it must likewise add:
        #
        # Connection: Keep-Alive
        #
        # to the response.
        #
        # For HTTP 1.1, Keep-Alive is assumed.  If a client does not want
        # Keep-Alive, then it must send the following header:
        #
        # Connection: close
        #
        # Likewise, if the server does not want to keep the connection
        # alive, it must send the same header:
        #
        # Connection: close
        #
        # to the client.
        
        if @name
          unless @webserver.respond_to?(:keepalive) && @webserver.keepalive(@name) == false
            if @http_version == C1_0
              if data =~ /Connection: Keep-Alive/i
                # Nonstandard HTTP 1.0 situation; apply keepalive header.
                @connection_header = CConnection_KeepAlive
              else
                # Standard HTTP 1.0 situation; connection will be closed.
                @keepalive = false
                @connection_header = CConnection_close
              end
            else # The connection is an HTTP 1.1 connection.
              if data =~ /Connection: [Cc]lose/
                # Nonstandard HTTP 1.1 situation; connection will be closed.
                @keepalive = false
              end
            end
          end
          
          @webserver.add_client(self,@data,data) if @webserver.respond_to?(:add_client)
        else
          raise Http404Error
        end           
      else
        @data.push data
        @header_missing_pieces = true
      end
    end
  end
  
  # The push method pushes data from the HttpRecognizer to whatever
  # entity is responsible for handling it. You MUST override this with
  # something useful.

  def push
    raise NotImplemented
  end

  def request_method; @request_method; end
  def http_version; @http_version; end
  def none_match; @none_match; end

  def setup_for_redeployment
    @data_pos = 0
  end

end
