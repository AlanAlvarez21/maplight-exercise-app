require "net/http"
require "json"
require "cgi"

class WeatherService
  module Errors
    class Error < StandardError; end
    class ApiError < Error; end
    class GeocodingError < Error; end
    class ApiKeyMissingError < Error; end
    class ZipCodeNotFoundError < Error; end
  end
  API_BASE_URL = "https://api.openweathermap.org/data/2.5"
  GEO_API_BASE_URL = "https://api.openweathermap.org/geo/1.0"

  def self.api_key
    @api_key ||= ENV["OPENWEATHER_API_KEY"] || Rails.application.credentials.openweather_api_key rescue nil
  end

  def get_forecast(address)
    # Validate input
    raise ArgumentError, "Address cannot be blank" if address.blank?

    # Check if API key is configured
    unless self.class.api_key
      Rails.logger.warn "OpenWeather API key is not configured"
      raise WeatherService::Errors::ApiKeyMissingError, "OpenWeather API key is not configured. Please set OPENWEATHER_API_KEY environment variable."
    end

    # First, try to find any cached data for this address (to avoid API calls when possible)
    normalized_address = generate_cache_key(address)
    # Look for any fresh cache entry for this address regardless of location
    cache_entry = WeatherCache.fresh.find_by(address: normalized_address)
    
    if cache_entry
      Rails.logger.info "Returning cached weather data for: #{address}"
      weather_data = JSON.parse(cache_entry.data, symbolize_names: true)
      return {
        cached: true,
        data: WeatherData::CurrentWeather.new(weather_data),
        cached_at: cache_entry.created_at
      }
    end

    # If no cached data exists for this address, geocode the address to get coordinates
    coordinates = geocode_address(address)
    unless coordinates
      Rails.logger.error "Failed to geocode address: #{address}"
      return {
        cached: false,
        data: nil
      }
    end

    # If geocoding returned a not_found error, raise specific error for the controller
    if coordinates.is_a?(Hash) && coordinates[:error] == "not_found"
      raise WeatherService::Errors::ZipCodeNotFoundError, "ZIP code '#{address}' does not exist. Please enter a valid ZIP code."
    end
    
    # Look for cached data in WeatherCache model using address and coordinates
    cache_entry = WeatherCache.fresh.find_by(address: normalized_address, location: "#{coordinates[:lat]},#{coordinates[:lon]}")
    
    if cache_entry
      Rails.logger.info "Returning cached weather data for: #{address}"
      weather_data = JSON.parse(cache_entry.data, symbolize_names: true)
      return {
        cached: true,
        data: WeatherData::CurrentWeather.new(weather_data),
        cached_at: cache_entry.created_at
      }
    end

    # Do NOT return expired cache data - instead, fetch fresh data from API

    # If not in cache, fetch from API
    begin
      # Get weather data from API
      raw_weather_data = fetch_weather_data(coordinates[:lat], coordinates[:lon])

      # Save to cache using the WeatherCache model
      cache_weather_data(generate_cache_key(address), coordinates, raw_weather_data)

      Rails.logger.info "Fetched fresh weather data for: #{address}"
      {
        cached: false,
        data: WeatherData::CurrentWeather.new(raw_weather_data)
      }
    rescue => e
      Rails.logger.error "Error fetching weather data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Handle different types of errors appropriately
      case e
      when Net::TimeoutError, Net::OpenTimeout
        raise WeatherService::ApiError, "API request timed out"
      when Net::HTTPError
        raise WeatherService::ApiError, "API returned HTTP error: #{e.message}"
      else
        raise e
      end
    end
  end

  private

  def geocode_address(address)
    # Sanitize the address first
    sanitized_address = address.to_s.strip

    # If the address looks like a ZIP code (all digits), prioritize ZIP code API endpoints first
    if sanitized_address.match?(/^\d+$/)
      Rails.logger.info "Address '#{sanitized_address}' appears to be a ZIP code, prioritizing ZIP code API endpoints"

      # First try the US ZIP code API endpoint (most common case)
      coordinates = try_zip_geocoding(sanitized_address, "US")
      return coordinates if coordinates && !coordinates[:error]

      # Try ZIP code API endpoints for common countries
      common_zip_countries = [ "CA", "MX", "GB", "ES", "FR", "DE", "IT", "JP", "AU" ]
      common_zip_countries.each do |country|
        coordinates = try_zip_geocoding(sanitized_address, country)
        return coordinates if coordinates && !coordinates[:error]
      end
      
      # If all ZIP code attempts resulted in 'not_found' errors, we can confidently say the ZIP doesn't exist
      if coordinates && coordinates[:error] == "not_found"
        Rails.logger.info "ZIP code #{sanitized_address} does not exist in any of the attempted countries"
        return coordinates
      end
      
      # If it looks like a Mexican postal code specifically in the Guadalajara area
      if sanitized_address.match?(/^(44|45|46|47)\d{3}$/)
        coordinates = try_geocoding_address("Guadalajara,MX")
        return coordinates if coordinates
      end
    end

    # Try the original address format (might work for specific locations)
    coordinates = try_geocoding_address(sanitized_address)
    return coordinates if coordinates

    # Try with common formats for international addresses - only if not already tried as ZIP code
    unless sanitized_address.match?(/^\d+$/)
      common_countries = [ "US", "CA", "GB", "MX", "ES", "FR", "DE", "IT", "JP", "AU" ]
      common_countries.each do |country|
        coordinates = try_geocoding_address("#{sanitized_address},#{country}")
        return coordinates if coordinates
      end
    end
    
    # As a final fallback, try the address with country codes
    coordinates = try_geocoding_address("#{sanitized_address},US") || 
                  try_geocoding_address("#{sanitized_address},MX") rescue nil
    
    return coordinates if coordinates

    Rails.logger.error "Failed to geocode address: #{sanitized_address} using multiple formats"
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
      # Return a special indicator for 404 errors which typically means ZIP code doesn't exist
      if response.code == "404"
        return { error: "not_found", message: response.body }
      end
      nil
    end
  end

  def fetch_weather_data(lat, lon)
    # Get current weather and forecast
    current_uri = URI("#{API_BASE_URL}/weather?lat=#{lat}&lon=#{lon}&units=imperial&appid=#{self.class.api_key}")
    forecast_uri = URI("#{API_BASE_URL}/forecast?lat=#{lat}&lon=#{lon}&units=imperial&appid=#{self.class.api_key}")

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

    # Process forecast data
    if forecast_data && forecast_data["list"]
      # Get hourly forecast (first 8 items = 24 hours)
      hourly_forecasts = forecast_data["list"].first(8).map do |item|
        dt = Time.at(item["dt"])
        {
          time: dt.strftime("%l:00 %p").strip, # e.g., "2 PM", "3 PM"
          temp: item.dig("main", "temp")&.round,
          condition: item.dig("weather", 0, "description"),
          icon: item.dig("weather", 0, "icon")
        }
      end

      # Get daily forecast (group by day and select key data points)
      daily_forecasts = {}
      forecast_data["list"].each do |item|
        dt = Time.at(item["dt"])
        day_key = dt.strftime("%m/%d")
        
        if daily_forecasts[day_key]
          # Update high/low temps for the day
          temp = item.dig("main", "temp")
          daily_forecasts[day_key][:high] = [temp&.round || 0, daily_forecasts[day_key][:high]].max
          daily_forecasts[day_key][:low] = [temp&.round || Float::INFINITY, daily_forecasts[day_key][:low]].min
          # Use the condition and icon from the first occurrence of the day unless there's rain/snow which should take priority
          current_condition = daily_forecasts[day_key][:condition].to_s.downcase
          new_condition = item.dig("weather", 0, "description").to_s.downcase
          # Prioritize precipitation conditions over others
          if !current_condition.include?("rain") && !current_condition.include?("snow") && (new_condition.include?("rain") || new_condition.include?("snow"))
            daily_forecasts[day_key][:condition] = item.dig("weather", 0, "description")
            daily_forecasts[day_key][:icon] = item.dig("weather", 0, "icon")
          end
        else
          daily_forecasts[day_key] = {
            day: dt.strftime("%A"),
            date: day_key,
            high: item.dig("main", "temp_max")&.round,
            low: item.dig("main", "temp_min")&.round,
            condition: item.dig("weather", 0, "description"),
            icon: item.dig("weather", 0, "icon")
          }
        end
      end

      # Limit to 5 days
      weather_info[:hourly_forecast] = hourly_forecasts
      weather_info[:forecast] = daily_forecasts.values.first(5)
    else
      weather_info[:hourly_forecast] = []
      weather_info[:forecast] = []
    end

    weather_info
  end

  def generate_cache_key(address)
    # Normalize the address for consistent caching
    address.strip.downcase
  end

  def cache_weather_data(address, coordinates, weather_data)
    # Create cache entry using the WeatherCache model with 30-minute expiration
    cache_key = "weather_cache:#{generate_cache_key(address)}:#{coordinates[:lat]},#{coordinates[:lon]}"
    WeatherCache.create!(
      address: generate_cache_key(address),
      location: "#{coordinates[:lat]},#{coordinates[:lon]}",
      data: weather_data.to_json
    )
  rescue => e
    Rails.logger.error "Error caching weather data: #{e.message}"
  end
end
