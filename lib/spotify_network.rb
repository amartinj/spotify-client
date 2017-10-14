require 'excon'
require 'json'

module Spotify
  module Network
    def initialize_connections(config, base_uri)
      @access_token  = config[:access_token]
      @raise_errors  = config[:raise_errors] || false
      @retries       = config[:retries] || 0
      @read_timeout  = config[:read_timeout] || 10
      @write_timeout = config[:write_timeout] || 10
      @connection    = Excon.new(base_uri, persistent: config[:persistent] || false)
    end

    protected

    def run(verb, path, expected_status_codes, params = {}, headers = nil, idempotent = true)
      run!(verb, path, expected_status_codes, params, headers, idempotent)
    rescue Error => e
      if @raise_errors
        raise e
      else
        false
      end
    end

    def run!(verb, path, expected_status_codes, params_or_body = nil, headers = nil, idempotent = true)
      headers = headers || {
        'Content-Type' => 'application/json',
        'User-Agent'   => 'Spotify Ruby Client'
      }
      packet = {
        idempotent: idempotent,
        expects: expected_status_codes,
        method: verb,
        path: path,
        read_timeout: @read_timeout,
        write_timeout: @write_timeout,
        retry_limit: @retries,
        headers: headers
      }
      if params_or_body.is_a?(Hash)
        packet.merge!(query: params_or_body)
      else
        packet.merge!(body: params_or_body)
      end

      if !@access_token.nil? && @access_token != ''
        packet[:headers].merge!('Authorization' => "Bearer #{@access_token}")
      end

      # puts "\033[31m [Spotify] HTTP Request: #{verb.upcase} #{BASE_URI}#{path} #{packet[:headers].inspect} \e[0m"
      response = @connection.request(packet)
      ::JSON.load(response.body)

    rescue Excon::Errors::NotFound => exception
      raise(ResourceNotFound, "Error: #{exception.message}")
    rescue Excon::Errors::BadRequest => exception
      raise(BadRequest, "Error: #{exception.message}")
    rescue Excon::Errors::Forbidden => exception
      raise(InsufficientClientScopeError, "Error: #{exception.message}")
    rescue Excon::Errors::Unauthorized => exception
      raise(AuthenticationError, "Error: #{exception.message}")
    rescue Excon::Errors::Error => exception
      # Catch all others errors. Samples:
      #
      # <Excon::Errors::SocketError: Connection refused - connect(2) (Errno::ECONNREFUSED)>
      # <Excon::Errors::InternalServerError: Expected([200, 204, 404]) <=> Actual(500 InternalServerError)>
      # <Excon::Errors::Timeout: read timeout reached>
      # <Excon::Errors::BadGateway: Expected([200]) <=> Actual(502 Bad Gateway)>
      raise(HTTPError, "Error: #{exception.message}")
    end
  end
end