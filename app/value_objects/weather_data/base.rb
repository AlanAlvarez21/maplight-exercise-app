module WeatherData
  class Base
    def initialize(data)
      @data = data
    end

    protected

    def fetch_data(*keys)
      value = @data
      keys.each { |key| value = value&.dig(key) }
      value
    end
  end
end