require 'json'

require File.dirname(__FILE__) + '/spotify/utils'
require File.dirname(__FILE__) + '/spotify/exceptions'
require File.dirname(__FILE__) + '/spotify_network'

module Spotify
  class Client
    include Spotify::Network

    BASE_URI = 'https://api.spotify.com'.freeze

    attr_accessor :access_token

    # Initialize the client.
    #
    # @example
    #   client = Spotify::Client.new(:access_token => 'longtoken', retries: 0, raise_errors: true)
    #
    # @param [Hash] configuration.
    def initialize(config = {})
      initialize_connections(config, BASE_URI)
    end

    def inspect
      vars = instance_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(', ')
      "<#{self.class}: #{vars}>"
    end

    # Closes the connection underlying socket.
    # Use when you employ persistent connections and are done with your requests.
    def close_connection
      @connection.reset
    end

    def me
      run(:get, '/v1/me', [200])
    end

    def me_tracks
      run(:get, '/v1/me/tracks', [200])
    end

    # params:
    # - type: Required, The ID type, currently only 'artist' is supported
    # - limit: Optional. The maximum number of items to return. Default: 20. Minimum: 1. Maximum: 50.
    # - after: Optional. The last artist ID retrieved from the previous request.
    def me_following(params={})
      params = params.merge(type: 'artist')
      run(:get, "/v1/me/following", [200], params)
    end

    def user(user_id)
      run(:get, "/v1/users/#{user_id}", [200])
    end

    def user_playlists(user_id)
      run(:get, "/v1/users/#{user_id}/playlists", [200])
    end

    def user_playlist(user_id, playlist_id)
      run(:get, "/v1/users/#{user_id}/playlists/#{playlist_id}", [200])
    end

    def user_playlist_tracks(user_id, playlist_id, params = {})
      tracks = { 'items' => [] }
      path = "/v1/users/#{user_id}/playlists/#{playlist_id}/tracks"

      while path
        response = run(:get, path, [200], params)
        tracks['items'].concat(response.delete('items'))
        tracks.merge!(response)

        path = if response['next']
          response['next'].gsub(BASE_URI, '')
        else
          nil
        end
      end

      tracks
    end

    # Create a playlist for a Spotify user. The playlist will be empty until you add tracks.
    #
    # Requires playlist-modify-public for a public playlist.
    # Requires playlist-modify-private for a private playlist.
    def create_user_playlist(user_id, name, is_public = true)
      run(:post, "/v1/users/#{user_id}/playlists", [201], JSON.dump(name: name, public: is_public), nil, false)
    end

    # Add an Array of track uris to an existing playlist.
    #
    # Adding tracks to a user's public playlist requires authorization of the playlist-modify-public scope;
    # adding tracks to a private playlist requires the playlist-modify-private scope.
    #
    # client.add_user_tracks_to_playlist('1181346016', '7i3thJWDtmX04dJhFwYb0x', %w(spotify:track:4iV5W9uYEdYUVa79Axb7Rh spotify:track:2lzEz3A3XIFyhMDqzMdcss))
    def add_user_tracks_to_playlist(user_id, playlist_id, uris = [], position = nil)
      params = { uris: Array.wrap(uris)[0..99].join(',') }
      if position
        params.merge!(position: position)
      end
      run(:post, "/v1/users/#{user_id}/playlists/#{playlist_id}/tracks", [201], JSON.dump(params), nil, false)
    end

    # Removes tracks from playlist
    #
    # client.remove_user_tracks_from_playlist('1181346016', '7i3thJWDtmX04dJhFwYb0x', [{ uri: spotify:track:4iV5W9uYEdYUVa79Axb7Rh, positions: [0]}])
    def remove_user_tracks_from_playlist(user_id, playlist_id, tracks)
      run(:delete, "/v1/users/#{user_id}/playlists/#{playlist_id}/tracks", [200], JSON.dump(tracks: tracks))
    end

    # Replaces all occurrences of tracks with what's in the playlist
    #
    # client.replace_user_tracks_in_playlist('1181346016', '7i3thJWDtmX04dJhFwYb0x', %w(spotify:track:4iV5W9uYEdYUVa79Axb7Rh spotify:track:2lzEz3A3XIFyhMDqzMdcss))
    def replace_user_tracks_in_playlist(user_id, playlist_id, tracks)
      run(:put, "/v1/users/#{user_id}/playlists/#{playlist_id}/tracks", [201], JSON.dump(uris: tracks))
    end

    # Removes all tracks in playlist
    #
    # client.truncate_user_playlist('1181346016', '7i3thJWDtmX04dJhFwYb0x')
    def truncate_user_playlist(user_id, playlist_id)
      replace_user_tracks_in_playlist(user_id, playlist_id, [])
    end

    def album(album_id)
      run(:get, "/v1/albums/#{album_id}", [200])
    end

    def album_tracks(album_id)
      run(:get, "/v1/albums/#{album_id}/tracks", [200])
    end

    def albums(album_ids)
      params = { ids: Array.wrap(album_ids).join(',') }
      run(:get, '/v1/albums', [200], params)
    end

    def track(track_id)
      run(:get, "/v1/tracks/#{track_id}", [200])
    end

    def tracks(track_ids)
      params = { ids: Array.wrap(track_ids).join(',') }
      run(:get, '/v1/tracks', [200], params)
    end

    def artist(artist_id)
      run(:get, "/v1/artists/#{artist_id}", [200])
    end

    def artists(artist_ids)
      params = { ids: Array.wrap(artist_ids).join(',') }
      run(:get, '/v1/artists', [200], params)
    end

    def artist_albums(artist_id)
      run(:get, "/v1/artists/#{artist_id}/albums", [200])
    end

    def search(entity, term)
      unless [:artist, :album, :track].include?(entity.to_sym)
        fail(ImplementationError, "entity needs to be either artist, album or track, got: #{entity}")
      end
      run(:get, '/v1/search', [200], q: term.to_s, type: entity)
    end

    # Get Spotify catalog information about an artist's top 10 tracks by country.
    #
    # +country_id+ is required. An ISO 3166-1 alpha-2 country code.
    def artist_top_tracks(artist_id, country_id)
      run(:get, "/v1/artists/#{artist_id}/top-tracks", [200], country: country_id)
    end

    def related_artists(artist_id)
      run(:get, "/v1/artists/#{artist_id}/related-artists", [200])
    end

    # Follow artists or users
    #
    # client.follow('artist', ['0BvkDsjIUla7X0k6CSWh1I'])
    def follow(type, ids)
      params = { type: type, ids: Array.wrap(ids).join(',') }
      run(:put, "/v1/me/following", [204], params)
    end

    # Follow a playlist
    #
    # client.follow_playlist('lukebryan', '0obRj9nNySESpFelMCLSya')
    def follow_playlist(user_id, playlist_id, is_public = true)
      run(:put, "/v1/users/#{user_id}/playlists/#{playlist_id}/followers", [200], { public: is_public })
    end
  end
end
