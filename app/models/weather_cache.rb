class WeatherCache
  include ActiveModel::Model
  attr_accessor :address, :location, :data, :created_at

  def initialize(attributes = {})
    @address = attributes[:address]
    @location = attributes[:location]
    @data = attributes[:data]
    @created_at = attributes[:created_at] || Time.current
  end

  # This class is kept primarily for compatibility with the existing code structure
  # The actual caching is handled directly in Rails.cache in the WeatherService
end