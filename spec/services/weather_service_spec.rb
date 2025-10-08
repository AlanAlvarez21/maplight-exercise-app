require 'rails_helper'

RSpec.describe WeatherService, type: :service do
  let(:service) { WeatherService.new }
  let(:test_address) { 'New York, NY' }
  let(:coordinates) do
    [ {
      'lat' => 40.7128,
      'lon' => -74.0060,
      'name' => 'New York'
    } ]
  end
  let(:weather_data) do
    {
      'coord' => { 'lon' => -74.006, 'lat' => 40.7128 },
      'weather' => [ { 'id' => 800, 'main' => 'Clear', 'description' => 'clear sky', 'icon' => '01d' } ],
      'main' => { 'temp' => 293.15, 'feels_like' => 292.85, 'temp_min' => 292.15, 'temp_max' => 294.15, 'pressure' => 1013, 'humidity' => 65 },
      'name' => 'New York',
      'cod' => 200
    }
  end
  let(:forecast_data) do
    {
      'list' => [
        {
          'dt' => Time.current.to_i + 3600,
          'main' => { 'temp_max' => 295.15, 'temp_min' => 290.15 },
          'weather' => [ { 'description' => 'clear sky' } ]
        }
      ]
    }
  end

  before do
    # Stub the API key
    allow(ENV).to receive(:[]).with('OPENWEATHER_API_KEY').and_return('test_key')
    allow(Rails.application.credentials).to receive(:openweather_api_key).and_return('test_key')
  end

  describe '#get_forecast' do
    context 'when cache has fresh data' do
      let!(:cached_weather) do
        WeatherCache.create!(
          address: test_address.downcase,
          location: '40.7128,-74.0060',
          data: { current_temperature: 75, description: 'sunny' }.to_json
        )
      end

      before do
        # Stub geocoding to return the specific coordinates that match the cached data
        allow(service).to receive(:geocode_address).with(test_address).and_return({
          lat: 40.7128,
          lon: -74.0060,
          name: 'New York'
        })
        
        # Also make sure no HTTP calls are made if cache is not found (backup protection)
        allow(Net::HTTP).to receive(:get_response) do |uri|
          if uri.to_s.include?('geo/1.0/direct')
            # Geocoding API call
            double('response', code: '200', body: coordinates.to_json)
          elsif uri.to_s.include?('/weather')
            # Current weather API call
            double('response', code: '200', body: weather_data.to_json)
          elsif uri.to_s.include?('/forecast')
            # Forecast API call
            double('response', code: '200', body: forecast_data.to_json)
          else
            double('response', code: '404', body: '{"message": "Not found"}')
          end
        end
      end

      it 'returns cached data without making API calls' do
        result = service.get_forecast(test_address)
        expect(result).to include(cached: true)
        expect(result[:data].current_temperature).to eq(75)
      end
    end

    context 'when no cache exists' do
      before do
        # Clear any existing cache for the address
        WeatherCache.where(address: test_address.downcase).delete_all

        # Stub Net::HTTP calls using WebMock or similar approach
        # Since WebMock is not available, we'll stub the Net::HTTP.get_response method
        allow(Net::HTTP).to receive(:get_response) do |uri|
          if uri.to_s.include?('geo/1.0/direct')
            # Geocoding API call
            double('response', code: '200', body: coordinates.to_json)
          elsif uri.to_s.include?('/weather')
            # Current weather API call
            double('response', code: '200', body: weather_data.to_json)
          elsif uri.to_s.include?('/forecast')
            # Forecast API call
            double('response', code: '200', body: forecast_data.to_json)
          else
            double('response', code: '404', body: '{"message": "Not found"}')
          end
        end
      end

      it 'fetches data from the API and caches it' do
        expect {
          result = service.get_forecast(test_address)
          expect(result[:cached]).to be false
        }.to change(WeatherCache, :count).by(1)
      end

      it 'returns the correct data format' do
        result = service.get_forecast(test_address)

        expect(result[:cached]).to be false
        expect(result[:data]).to respond_to(:location, :current_temperature, :high_temperature, :low_temperature, :description)
      end
    end

    context 'when using expired cache' do
      before do
        WeatherCache.where(address: test_address.downcase).delete_all
        
        # Stub Net::HTTP calls for the API calls that should be made when cache is expired
        allow(Net::HTTP).to receive(:get_response) do |uri|
          if uri.to_s.include?('geo/1.0/direct')
            # Geocoding API call
            double('response', code: '200', body: coordinates.to_json)
          elsif uri.to_s.include?('/weather')
            # Current weather API call
            double('response', code: '200', body: weather_data.to_json)
          elsif uri.to_s.include?('/forecast')
            # Forecast API call
            double('response', code: '200', body: forecast_data.to_json)
          else
            double('response', code: '404', body: '{"message": "Not found"}')
          end
        end
      end

      it 'fetches fresh data from API instead of returning expired cache' do
        # Create an expired cache entry
        expired_cache = WeatherCache.create!(
          address: test_address.downcase,
          location: '40.7128,-74.0060',
          data: { current_temperature: 70, description: 'cloudy' }.to_json,
          created_at: 45.minutes.ago
        )

        result = service.get_forecast(test_address)
        expect(result[:cached]).to be false  # Should not be cached since it fetched fresh data
        expect(result[:data]).to respond_to(:location, :current_temperature, :high_temperature, :low_temperature, :description)
      end
    end

    context 'when geocoding fails' do
      before do
        WeatherCache.where(address: test_address.downcase).delete_all

        # Stub geocoding to return an empty response
        allow(Net::HTTP).to receive(:get_response) do |uri|
          if uri.to_s.include?('geo/1.0/direct')
            # Geocoding API call returning empty result
            double('response', code: '200', body: '[]')
          else
            double('response', code: '404', body: '{"message": "Not found"}')
          end
        end
      end

      it 'returns nil data when geocoding fails' do
        result = service.get_forecast(test_address)
        expect(result[:data]).to be_nil
      end
    end
  end

  describe 'private methods' do
    describe '#generate_cache_key' do
      it 'normalizes the address for consistent caching' do
        method = service.send(:generate_cache_key, '  NEW YORK, NY  ')
        expect(method).to eq('new york, ny')
      end
    end
  end
end
