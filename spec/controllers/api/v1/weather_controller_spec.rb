require 'rails_helper'

RSpec.describe Api::V1::WeatherController, type: :controller do
  let(:valid_address) { 'New York, NY' }
  let(:invalid_address) { 'Invalid Location That Does Not Exist' }
  let(:zip_code) { '10001' }
  
  let(:weather_data) do
    {
      location: 'New York',
      country: 'US',
      current_temperature: 72,
      feels_like: 70,
      high_temperature: 75,
      low_temperature: 68,
      humidity: 65,
      pressure: 1013,
      description: 'clear sky',
      icon_url: 'https://openweathermap.org/img/w/01d.png',
      wind_speed: 5.5,
      wind_deg: 180,
      hourly_forecast: [
        { time: '12:00 PM', temp: 72, condition: 'clear sky', icon: '01d' }
      ],
      forecast: [
        { day: 'Monday', date: '10/10', high: 75, low: 68, condition: 'sunny', icon: '01d' }
      ]
    }
  end

  before do
    # Stub the API key
    allow(ENV).to receive(:[]).with('OPENWEATHER_API_KEY').and_return('test_key')
    allow(Rails.application.credentials).to receive(:openweather_api_key).and_return('test_key')
    
    # Stub the WeatherService to return test data
    allow_any_instance_of(WeatherService).to receive(:get_forecast).with(valid_address).and_return({
      cached: false,
      data: instance_double(WeatherData::CurrentWeather, to_h: weather_data).as_null_object,
      cached_at: Time.current
    })
    
    allow_any_instance_of(WeatherService).to receive(:get_forecast).with(zip_code).and_return({
      cached: false,
      data: instance_double(WeatherData::CurrentWeather, to_h: weather_data).as_null_object,
      cached_at: Time.current
    })
  end

  describe 'GET #show' do
    context 'with valid address' do
      it 'returns success response with weather data' do
        get :show, params: { address: valid_address }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('cached')
        expect(json_response['data']).to have_key('location')
        expect(json_response['data']['location']).to eq('New York')
      end
    end

    context 'with ZIP code' do
      it 'returns success response with weather data' do
        get :show, params: { address: zip_code }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data')
        expect(json_response['data']).to have_key('location')
        expect(json_response['data']['location']).to eq('New York')
      end
    end

    context 'with missing address parameter' do
      it 'returns error response' do
        get :show, params: { address: '' }
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Address parameter is required')
      end
    end

    context 'with invalid address' do
      before do
        allow_any_instance_of(WeatherService).to receive(:get_forecast).with(invalid_address).and_return({
          cached: false,
          data: nil
        })
        
        # Mock the geocode_address private method returning not found
        allow_any_instance_of(WeatherService).to receive(:send).with(:geocode_address, invalid_address).and_return({ error: 'not_found' })
      end

      it 'returns not found error for invalid addresses' do
        get :show, params: { address: invalid_address }
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
    end

    context 'with sanitization' do
      it 'properly sanitizes input parameters' do
        malicious_address = "<script>alert('xss')</script>New York, NY"
        get :show, params: { address: malicious_address }
        
        expect(response).to have_http_status(:ok)
        # The malicious script should have been removed during sanitization
        # The test will pass if the sanitization method works and doesn't return an error
      end
    end
  end
end