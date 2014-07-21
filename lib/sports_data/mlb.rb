module Sportsdata
  module MLB
    # Returns upcoming games
    # @param dates [Array]
    # @param cache_key [#to_s] key to use when storing/retreiving game data
    # @return [Array]
    def self.games(dates, cache_key = Time.zone.today.to_date)
      Array(dates).reduce ([]) do |memo, date|
        memo += self.games_for_date(date, cache_key)
      end.flatten
    end

    protected

    # Returns games for a given date
    def self.games_for_date(date = Time.zone.today.to_date, cache_key)
      schedule = SportsData::MLB::ApiClient.new.daily_schedule(date).fetch("calendars").fetch("event") { {} }

      return [] unless schedule.any?

      Array.wrap(schedule).map do |event|
        SportsData::MLB::Game.new(event.fetch("id"), cache_key)
      end
    end
  end
end
