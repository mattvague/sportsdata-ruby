module SportsData
  module MLB
    class Venue
      attr_reader :uuid

      #
      # Instance methods
      #

      # @param venue_uuid [String] SportsData venue UUID for fetching venue data
      def initialize(venue_uuid)
        @uuid        = venue_uuid
        @api_client = ApiClient.new
        @sport = "MLB"
      end

      # Venue City
      #
      # @return [String]
      def location
        @location ||= venue_data && venue_data["market"]
      end

      # Venue Name
      #
      # @return [String]
      def name
        @name ||= venue_data && venue_data["name"]
      end

      private

      def venue_data
        venues.find { |v| v["id"] == uuid }
      end

      def venues
        Rails.cache.fetch ["venues"] do
          @venue ||= begin
            @venue = @api_client.venues
            @venue.fetch("venues").fetch("venue")
          end
        end
      end
    end
  end
end
