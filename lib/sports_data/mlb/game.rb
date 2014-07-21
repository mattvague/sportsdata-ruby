module SportsData
  module MLB
    class Game
      attr_accessor :uuid, :cache_key

      #
      # Instance methods
      #

      # @param event_uuid [String] SportsData event UUID for fetching statistics / boxscore
      def initialize(event_uuid, cache_key = Time.zone.today.to_date)
        @uuid        = event_uuid
        @cache_key   = cache_key
        @api_client = ApiClient.new
      end

      def sport
        "MLB"
      end

      # Statistics for home side
      #
      # @return [Game::Side]
      def home
        @home ||= Side.new(box_score.fetch(:home), stats.fetch(:home))
      end

      # Statistics for visitor side
      #
      # @return [Game::Side]
      def visitor
        @visitor ||= Side.new(box_score.fetch(:visitor), stats.fetch(:visitor))
      end

      # Whether the game is upcoming, in progress or finished
      #
      # @return [String] See http://developer.sportsdatallc.com/files/mlb_v4_glossary.xml for all possible statuses
      def status
        @status ||= box_score.fetch(:status)
      end

      # Winning side of game
      #
      # @return [Game::Side]
      def winner
        home.runs > visitor.runs ? home : visitor
      end

      # Losing side of game
      #
      # @return [Game::Side]
      def loser
        visitor.runs > home.runs ? home : visitor
      end

      # Difference in runs between winner and loser
      #
      # @return [Integer]
      def run_differential
        winner.runs - loser.runs
      end

      # Total number of innings for game
      #
      # @return [Integer]
      def innings
        @innings ||= box_score.fetch(:final) { {} }.fetch(:inning) { 0 } .to_i
      end

      # Location of game
      #
      # @return [String]
      def location
        @location ||= begin
          venue = Venue.new(event_info.fetch(:venue) { {} }.fetch(:id))
          venue.location.present? ? venue.location : venue.name
        end
      end

      # Start time of game
      #
      # @return [Time]
      def start_time
        Time.zone.parse(event_info.fetch(:scheduled_start_time).to_s)
      end

      # Checks whether a given team is playing in this game via short names
      #
      # @param short_name [Side, #short_name, #sport] team or object responding to #short_name
      # @return [true, false]
      def team_playing?(team)
        team.sport == sport && (home == team || visitor == team)
      end

      private

      def stats
        Rails.cache.fetch ["games", "stats", @cache_key, uuid] do
          @stats ||= begin
            @api_client.game_statistics(uuid)
              .fetch("statistics")
              .with_indifferent_access
          end
        end
      end

      def box_scores
        Rails.cache.fetch ["games", "daily_box_score", @cache_key, start_time.to_date] do
          @api_client.daily_box_score(start_time.to_date).fetch("boxscores")
        end
      end

      def box_score
        @box_score ||= begin
          box_score = box_scores.fetch("boxscore").select { |b| b["id"] == uuid }.last
          (box_score || {}).with_indifferent_access
        end
      end

      def event_info
        Rails.cache.fetch ["games", "event_info", @cache_key, uuid] do
          @event_info ||= begin
            @api_client.event_info(uuid).fetch("event").with_indifferent_access
          end
        end
      end

      class Side
        attr_accessor :box_score, :stats

        # Allow equality comparisons to objects respond to short_name
        #
        # @param obj [#short_name]
        # @return [String]
        def ==(obj)
          obj.respond_to?(:short_name) ? obj.short_name == short_name : super(obj)
        end

        def initialize(box_score, stats)
          @box_score = box_score
          @stats     = stats
        end

        # Short name for this side
        #
        # @example SEA, NYY, etc
        #
        # @return [String]
        def short_name
          @short_name ||= box_score.fetch(:abbr)
        end

        # Total number of runs for this side
        #
        # @return [Integer]
        def runs
          @runs ||= box_score.fetch(:runs) { [] }[0].to_i
        end
        alias_method :score, :runs

        # Total number of hist for this side
        #
        # @return [Integer]
        def hits
          @hits ||= box_score.fetch(:hits) { 0 }.to_i
        end

        # Number of homeruns for this side
        #
        # @return [Integer]
        def homeruns
          @homeruns ||= events.select {|r| r.fetch(:hitter_outcome) == "aHR" }.count
        end
        
        # Number of strikeouts for this side
        #
        # @return [Integer]
        def strikeouts
          @strik_outs ||= events.select {|r| ["kKL", "kKS"].include?(r.fetch(:hitter_outcome)) }.count
        end

        # Whether a save occured in this game
        #
        # @return [true, false]
        def save?
          @save ||= stats.fetch(:pitching).fetch(:team).fetch(:games).fetch(:save) == "1"
        end

        # Whether a blown-save occured in this game
        #
        # @return [true, false]
        def blown_save?
          @blown_save ||= stats.fetch(:pitching).fetch(:team).fetch(:games).fetch(:blown_save) == "1"
        end

        # Whether a pitcher pitched the entire game
        #
        # @return [true, false]
        def complete?
          @complete ||= stats.fetch(:pitching).fetch(:team).fetch(:games).fetch(:complete) == "1"
        end

        # Whether a shutout occured
        #
        # @return [true, false]
        def shutout?
          @shutout ||= stats.fetch(:pitching).fetch(:team).fetch(:games).fetch(:shutout) == "1"
        end

        # Number of triple plays that occured
        #
        # @return [Integer]
        def triple_plays
          @triple_plays ||= stats.fetch(:fielding).fetch(:team).fetch(:tp).to_i
        end

        # Number of cycles that occured
        #
        # @return [Integer]
        def cycles
          @cycles ||= players.select do |player|
            player.fetch(:onbase).fetch(:s).to_i > 0 &&
              player.fetch(:onbase).fetch(:d).to_i > 0 &&
              player.fetch(:onbase).fetch(:t).to_i > 0
          end.count
        end

        private

        def events
          runs = box_score.fetch(:runs).is_a?(Array) ? box_score.fetch(:runs).last : box_score.fetch(:runs)
          Array.wrap(runs.fetch(:event))
        end

        def players
          stats.fetch(:hitting).fetch(:players).fetch(:player)
        end
      end
    end
  end
end
