require "net/http"
require "json"
require "cgi"

class WeatherService
  API_BASE_URL = "https://api.openweathermap.org/data/2.5"
  GEO_API_BASE_URL = "https://api.openweathermap.org/geo/1.0"

  def self.api_key
    @api_key ||= ENV["OPENWEATHER_API_KEY"] || Rails.application.credentials.openweather_api_key rescue nil
  end

  def get_forecast(address)
    # Check if API key is configured
    unless self.class.api_key
      Rails.logger.warn "OpenWeather API key is not configured"
      # Try to return cached data if available
      # For this, we'd need to know coordinates, but without API key we can't geocode
      # So we can't return cached data without knowing the coordinates
      raise "OpenWeather API key is not configured. Please set OPENWEATHER_API_KEY environment variable."
    end

    # First, try to find in cache
    # Look for cached data using various possible cache keys
    normalized_address = generate_cache_key(address)
    
    # Look for cached data by trying different possible coordinate combinations
    # Since we don't know the exact coordinates ahead of time, we'll need to
    # implement a different caching strategy - cache using just the normalized address
    cache_key = "weather_cache:#{normalized_address}:*"
    
    # Actually, for this implementation, let's use a simpler approach:
    # We'll cache using the normalized address and let the geocoding happen every time
    # Or better yet, update our approach to cache using a combination of address and coordinates once known
    
    # The original approach: try to find cached data based on address and coordinates
    # Since we don't know coordinates until after geocoding, we'll just check the cache after geocoding
    coordinates = geocode_address(address)
    unless coordinates
      Rails.logger.error "Failed to geocode address: #{address}"
      # Return a result with nil data instead of raising an exception
      return {
        cached: false,
        data: nil
      }
    end
    
    cache_key = "weather_cache:#{normalized_address}:#{coordinates[:lat]},#{coordinates[:lon]}"
    cached_data = nil
    begin
      cached_data = Rails.cache.read(cache_key)
    rescue Redis::BaseError, Redis::CannotConnectError => e
      Rails.logger.warn "Redis connection error while reading cache: #{e.message}"
      # Continue with API call if cache is unavailable
    end
    
    if cached_data
      Rails.logger.info "Returning cached weather data for: #{address}"
      return {
        cached: true,
        data: JSON.parse(cached_data[:data], symbolize_names: true),
        cached_at: cached_data[:created_at]
      }
    end

    # Do NOT return expired cache data - instead, fetch fresh data from API

    # If not in cache and within limits, fetch from API
    begin
      # Geocode the address to get coordinates
      coordinates = geocode_address(address)
      unless coordinates
        Rails.logger.error "Failed to geocode address: #{address}"
        # Return a result with nil data instead of raising an exception
        return {
          cached: false,
          data: nil
        }
      end

      # Now that we have coordinates, construct the full cache key
      full_cache_key = "weather_cache:#{generate_cache_key(address)}:#{coordinates[:lat]},#{coordinates[:lon]}"
      
      # Check again with the specific coordinates (in case multiple locations have same name)
      cached_data_with_coords = nil
      begin
        cached_data_with_coords = Rails.cache.read(full_cache_key)
      rescue Redis::BaseError, Redis::CannotConnectError => e
        Rails.logger.warn "Redis connection error while reading cache: #{e.message}"
        # Continue with API call if cache is unavailable
      end
      
      if cached_data_with_coords
        Rails.logger.info "Returning cached weather data for: #{address}"
        return {
          cached: true,
          data: JSON.parse(cached_data_with_coords[:data], symbolize_names: true),
          cached_at: cached_data_with_coords[:created_at]
        }
      end

      # Get weather data from API
      weather_data = fetch_weather_data(coordinates[:lat], coordinates[:lon])

      # Save to cache
      cache_weather_data(generate_cache_key(address), coordinates, weather_data)

      Rails.logger.info "Fetched fresh weather data for: #{address}"
      {
        cached: false,
        data: weather_data
      }
    rescue => e
      Rails.logger.error "Error fetching weather data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def geocode_address(address)
    # If the address looks like a ZIP code (all digits), prioritize ZIP code API endpoints first
    if address.match?(/^\d+$/)
      Rails.logger.info "Address '#{address}' appears to be a ZIP code, prioritizing ZIP code API endpoints"

      # First try the US ZIP code API endpoint (most common case)
      coordinates = try_zip_geocoding(address, "US")
      return coordinates if coordinates

      # Try ZIP code API endpoints for common countries
      common_zip_countries = [ "CA", "MX", "GB", "ES", "FR", "DE", "IT", "JP", "AU" ]
      common_zip_countries.each do |country|
        coordinates = try_zip_geocoding(address, country)
        return coordinates if coordinates
      end
    end

    # Try the original address format (might work for specific locations)
    coordinates = try_geocoding_address(address)
    return coordinates if coordinates

    # If ZIP code approach didn't work, try with country codes
    if address.match?(/^\d+$/)
      coordinates = try_geocoding_address("#{address},US")
      return coordinates if coordinates
    end

    # Try with Mexico as default for Mexican postal codes
    coordinates = try_geocoding_address("#{address},MX")
    return coordinates if coordinates

    # Try ZIP code API endpoint for Mexico (for non-US zip codes)
    coordinates = try_zip_geocoding(address, "MX")
    return coordinates if coordinates

    # For Mexican postal codes specifically, try searching for Guadalajara if that's the area
    if address.match?(/^(44|45|46|47)\d{3}$/) # Mexican postal codes for Guadalajara area typically start with 44, 45, 46, 47
      coordinates = try_geocoding_address("Guadalajara,MX")
      return coordinates if coordinates
    end

    # Try with common formats for international addresses
    common_countries = [ "US", "CA", "GB", "MX", "ES", "FR", "DE", "IT", "JP", "AU" ]
    common_countries.each do |country|
      coordinates = try_geocoding_address("#{address},#{country}")
      return coordinates if coordinates

      # Also try ZIP code API for each country as fallback
      coordinates = try_zip_geocoding(address, country)
      return coordinates if coordinates
    end

    Rails.logger.error "Failed to geocode address: #{address} using multiple formats"
    nil
  end

  def try_geocoding_address(address)
    uri = URI("#{GEO_API_BASE_URL}/direct?q=#{CGI.escape(address)}&limit=1&appid=#{self.class.api_key}")
    Rails.logger.info "Making geocoding request to: #{uri}"
    response = Net::HTTP.get_response(uri)
    Rails.logger.info "Geocoding response code: #{response.code}, body: #{response.body}"

    if response.code == "200"
      data = JSON.parse(response.body)
      if data.is_a?(Array) && data.first
        {
          lat: data.first["lat"],
          lon: data.first["lon"],
          name: data.first["name"]
        }
      else
        Rails.logger.error "Geocoding returned 200 but no valid data: #{response.body}"
        nil
      end
    else
      Rails.logger.error "Geocoding API error: #{response.code} - #{response.body}"
      nil
    end
  end

  def try_zip_geocoding(zip_code, country_code)
    uri = URI("#{GEO_API_BASE_URL}/zip?zip=#{CGI.escape(zip_code)},#{country_code}&appid=#{self.class.api_key}")
    Rails.logger.info "Making ZIP geocoding request to: #{uri}"
    response = Net::HTTP.get_response(uri)
    Rails.logger.info "ZIP geocoding response code: #{response.code}, body: #{response.body}"

    if response.code == "200"
      data = JSON.parse(response.body)
      if data.is_a?(Hash) && data["lat"] && data["lon"]
        {
          lat: data["lat"],
          lon: data["lon"],
          name: data["name"] || "#{zip_code}, #{country_code}"
        }
      else
        Rails.logger.error "ZIP geocoding returned 200 but no valid data: #{response.body}"
        nil
      end
    else
      Rails.logger.error "ZIP geocoding API error: #{response.code} - #{response.body}"
      nil
    end
  end

  def fetch_weather_data(lat, lon)
    # Get current weather and forecast
    current_uri = URI("#{API_BASE_URL}/weather?lat=#{lat}&lon=#{lon}&units=imperial&appid=#{self.class.api_key}")
    forecast_uri = URI("#{API_BASE_URL}/forecast?lat=#{lat}&lon=#{lon}&units=imperial&cnt=5&appid=#{self.class.api_key}")

    current_response = Net::HTTP.get_response(current_uri)
    forecast_response = Net::HTTP.get_response(forecast_uri)

    current_data = JSON.parse(current_response.body) if current_response.code == "200"
    forecast_data = JSON.parse(forecast_response.body) if forecast_response.code == "200"

    # Extract needed information
    weather_info = {
      location: current_data&.dig("name") || "Unknown Location",
      country: current_data&.dig("sys", "country"),
      current_temperature: current_data&.dig("main", "temp")&.round,
      feels_like: current_data&.dig("main", "feels_like")&.round,
      high_temperature: current_data&.dig("main", "temp_max")&.round,
      low_temperature: current_data&.dig("main", "temp_min")&.round,
      humidity: current_data&.dig("main", "humidity"),
      pressure: current_data&.dig("main", "pressure"),
      description: current_data&.dig("weather", 0, "description"),
      icon_id: current_data&.dig("weather", 0, "icon"),
      icon_url: current_data&.dig("weather", 0, "icon") ? "https://openweathermap.org/img/w/#{current_data['weather'][0]['icon']}.png" : nil,
      wind_speed: current_data&.dig("wind", "speed"),
      wind_deg: current_data&.dig("wind", "deg")
    }

    # Process forecast data (5-day forecast)
    if forecast_data && forecast_data["list"]
      weather_info[:forecast] = forecast_data["list"].first(5).map do |day|
        dt = Time.at(day["dt"])
        {
          day: dt.strftime("%A"),
          date: dt.strftime("%m/%d"),
          high: day.dig("main", "temp_max")&.round,
          low: day.dig("main", "temp_min")&.round,
          condition: day.dig("weather", 0, "description")
        }
      end
    else
      weather_info[:forecast] = []
    end

    weather_info
  end

  def generate_cache_key(address)
    # Normalize the address for consistent caching
    address.strip.downcase
  end

  def cache_weather_data(address, coordinates, weather_data)
    # Create cache entry using Rails.cache with 30-minute expiration
    cache_key = "weather_cache:#{generate_cache_key(address)}:#{coordinates[:lat]},#{coordinates[:lon]}"
    Rails.cache.write(cache_key, {
      address: generate_cache_key(address),
      location: "#{coordinates[:lat]},#{coordinates[:lon]}",
      data: weather_data.to_json,
      created_at: Time.current
    }, expires_in: 30.minutes)
  rescue Redis::BaseError, Redis::CannotConnectError => e
    Rails.logger.error "Redis connection error while caching weather data: #{e.message}"
    # Don't raise the error, just log it - the app should still work without caching
  rescue => e
    Rails.logger.error "Error caching weather data: #{e.message}"
  end
end
