module SportsData
  module MLB
    class ApiClient
      BASE_URI    = "http://api.sportsdatallc.org/mlb-t4"
      API_KEY     = Rails.configuration.x.sportsdata.api_key

      # Queries SportsData's daily schedule API
      #
      # @param date [Date] day to find schedule for (defaults to today)
      # @return [Hash]
      def daily_schedule(date = Time.zone.today.to_date)
        date = date.to_date
        yyyy, mm, dd = date_to_yyyy_mm_dd(date)

        get("daily/schedule/#{yyyy}/#{mm}/#{dd}.xml").body
      end

      # Queries SportsData's daily box score API
      #
      # @param date [Date] day to find box score for (defaults to today)
      # @return [Hash]
      def daily_event_info(date = Time.zone.today.to_date)
        date = date.to_date
        yyyy, mm, dd = date_to_yyyy_mm_dd(date)

        get("daily/event/#{yyyy}/#{mm}/#{dd}.xml").body
      end

      # Queries SportsData's daily box score API
      #
      # @param date [Date] day to find box score for (defaults to today)
      # @return [Hash]
      def daily_box_score(date = Time.zone.today.to_date)
        date = date.to_date
        yyyy, mm, dd = date_to_yyyy_mm_dd(date)

        get("daily/boxscore/#{yyyy}/#{mm}/#{dd}.xml").body
      end
      # Queries SportsData's game stats API
      #
      # @param event_uuid [String] the game's UUID
      # @return [Hash]
      def game_statistics(event_uuid)
        get("statistics/#{event_uuid}.xml").body
      end


      # Queries SportsData's game box score API
      #
      # @param event_uuid [String] the game's UUID
      # @return [Hash]
      def game_box_score(event_uuid)
        get("boxscore/#{event_uuid}.xml").body
      end

      # Queries SportsData's event info API
      #
      # @param event_uuid [String] the game's UUID
      # @return [Hash]
      def event_info(event_uuid)
        get("event/#{event_uuid}.xml").body
      end

      # Queries SportsData's venues API
      # @return [Array] Array of venues
      def venues
        get("venues/venues.xml").body
      end

      private

      # Queries SportsData's daily schedule API
      #
      # @option options [Date] :date day to find schedule for (defaults to today)
      # @return [Hash]
      def connection
        @connection ||= Faraday.new(url: BASE_URI) do |conn|
          conn.use :http_cache, store: Rails.cache, logger: ActiveSupport::Logger.new(STDOUT)
          conn.request :rate_limit, max: 3, interval: 1,
                       interval_randomness: 0.5, backoff_factor: 2
          conn.adapter Faraday.default_adapter
          conn.params[:api_key] = API_KEY
          conn.response :xml, :content_type => /\bxml$/
          conn.use Faraday::Response::RaiseError
        end
      end

      def get(url, params = {})
        connection.get(url, params)
      end

      # Converts a date into an array of YYYY MM DD
      #
      # @param date [Date] date to convert
      # @return [Array] date array e.g. ["2013", "10", 11"]
      def date_to_yyyy_mm_dd(date)
        date.strftime("%Y/%m/%d").split("/")
      end
    end
  end
end
