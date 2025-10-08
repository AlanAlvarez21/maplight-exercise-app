module WeatherData
  class CurrentWeather < Base
    def initialize(data)
      @data = data
    end

    def location
      fetch_data(:location)
    end

    def country
      fetch_data(:country)
    end

    def current_temperature
      fetch_data(:current_temperature)
    end

    def feels_like
      fetch_data(:feels_like)
    end

    def high_temperature
      fetch_data(:high_temperature)
    end

    def low_temperature
      fetch_data(:low_temperature)
    end

    def humidity
      fetch_data(:humidity)
    end

    def pressure
      fetch_data(:pressure)
    end

    def description
      fetch_data(:description)
    end

    def icon_url
      fetch_data(:icon_url)
    end

    def wind_speed
      fetch_data(:wind_speed)
    end

    def wind_deg
      fetch_data(:wind_deg)
    end

    def hourly_forecast
      @hourly_forecast ||= begin
        hourly_data = fetch_data(:hourly_forecast)
        if hourly_data.is_a?(Array)
          hourly_data.map { |item| HourlyForecast.new(item) }
        else
          []
        end
      end
    end

    def forecast
      @forecast ||= begin
        forecast_data = fetch_data(:forecast)
        if forecast_data.is_a?(Array)
          forecast_data.map { |item| DailyForecast.new(item) }
        else
          []
        end
      end
    end

    def to_h
      @data
    end
  end

  class HourlyForecast < Base
    def time
      fetch_data(:time)
    end

    def temp
      fetch_data(:temp)
    end

    def condition
      fetch_data(:condition)
    end

    def icon
      fetch_data(:icon)
    end
  end

  class DailyForecast < Base
    def day
      fetch_data(:day)
    end

    def date
      fetch_data(:date)
    end

    def high
      fetch_data(:high)
    end

    def low
      fetch_data(:low)
    end

    def condition
      fetch_data(:condition)
    end

    def icon
      fetch_data(:icon)
    end
  end
end