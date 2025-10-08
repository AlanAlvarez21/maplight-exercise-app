class Api::V1::WeatherController < ApplicationController
  before_action :validate_and_sanitize_params, only: [:show]
  
  def show
    address = params[:address]
    
    if address.blank?
      render json: { error: "Address parameter is required" }, status: :bad_request
      return
    end

    begin
      weather_result = WeatherService.new.get_forecast(address)
      weather_data = weather_result[:data]

      if weather_data
        render json: {
          cached: weather_result[:cached],
          cached_at: weather_result[:cached_at],
          data: format_weather_data(weather_data)
        }
      else
        coordinates = WeatherService.new.send(:geocode_address, address)
        if coordinates.is_a?(Hash) && coordinates[:error] == "not_found"
          render json: { error: "ZIP code '#{address}' does not exist. Please enter a valid ZIP code." }, status: :not_found
        else
          render json: { error: "Could not retrieve weather data for '#{address}'" }, status: :unprocessable_entity
        end
      end
    rescue WeatherService::Errors::ApiKeyMissingError => e
      Rails.logger.error "API key missing: #{e.message}"
      render json: { error: "The weather service is temporarily unavailable." }, status: :service_unavailable
    rescue WeatherService::Errors::ZipCodeNotFoundError => e
      Rails.logger.warn "ZIP code not found: #{e.message}"
      render json: { error: e.message }, status: :not_found
    rescue WeatherService::Errors::ApiError => e
      Rails.logger.error "Weather API error: #{e.message}"
      render json: { error: "There was an issue retrieving weather data." }, status: :service_unavailable
    rescue => e
      Rails.logger.error "Error retrieving weather forecast: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "An error occurred while retrieving weather data: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def validate_and_sanitize_params
    # Sanitize all parameters that come in
    params.transform_values! { |value| sanitize_address(value) }
  end

  def sanitize_address(address)
    return nil if address.blank?
    # Remove any potentially harmful characters and sanitize the input
    ActionController::Base.helpers.sanitize(address.to_s, tags: []).gsub(/[<>'"\\]/, '').strip
  end

  def format_weather_data(weather_data)
    # Format the value object data for JSON response
    {
      location: weather_data.location,
      country: weather_data.country,
      current_temperature: weather_data.current_temperature,
      feels_like: weather_data.feels_like,
      high_temperature: weather_data.high_temperature,
      low_temperature: weather_data.low_temperature,
      humidity: weather_data.humidity,
      pressure: weather_data.pressure,
      description: weather_data.description,
      icon_url: weather_data.icon_url,
      wind_speed: weather_data.wind_speed,
      wind_deg: weather_data.wind_deg,
      hourly_forecast: weather_data.hourly_forecast.map do |hourly|
        {
          time: hourly.time,
          temp: hourly.temp,
          condition: hourly.condition,
          icon: hourly.icon
        }
      end,
      forecast: weather_data.forecast.map do |daily|
        {
          day: daily.day,
          date: daily.date,
          high: daily.high,
          low: daily.low,
          condition: daily.condition,
          icon: daily.icon
        }
      end
    }
  end
end