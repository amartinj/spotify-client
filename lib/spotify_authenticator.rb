require File.dirname(__FILE__) + '/spotify_network'
require 'base64'

module Spotify
  class Authenticator
    include Spotify::Network

    BASE_URI = 'https://accounts.spotify.com'.freeze

    def initialize(config, refresh_token)
      @refresh_token = refresh_token
      @redirect_uri = config[:redirect_uri]
      @client_id = config[:client_id]
      @client_secret = config[:client_secret]
      initialize_connections(config, BASE_URI)
    end

    def authorization_url
      state = Base64.urlsafe_encode64(Time.now.to_i.to_s)
      params = {
        client_id: @client_id,
        response_type: 'code',
        redirect_uri: @redirect_uri,
        state: state,
        show_dialog: false
      }
      "#{BASE_URI}/authorize?#{URI.encode_www_form(params)}"
    end

    def new_token
      params = {
        grant_type: 'refresh_token',
        redirect_uri: @redirect_uri,
        client_id: @client_id,
        client_secret: @client_secret,
        refresh_token: @refresh_token
      }
      run(:post, '/api/token', [200], params, headers)['access_token']
    end

    protected

    def headers
      {'Content-Type' => 'application/x-www-form-urlencoded'}
    end
  end
end
