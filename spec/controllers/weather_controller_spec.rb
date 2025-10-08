require 'rails_helper'

RSpec.describe WeatherController, type: :controller do
  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
      expect(response).to have_http_status(:ok)
    end

    it 'assigns default values when no address is provided' do
      get :index
      expect(assigns(:address)).to be_nil
      expect(response).to be_successful
    end
  end

  describe 'POST #forecast' do
    context 'when address is provided' do
      let(:valid_address) { 'New York, NY' }
      let(:weather_data) do
        {
          location: 'New York',
          current_temperature: 75,
          high_temperature: 80,
          low_temperature: 70,
          description: 'clear sky',
          forecast: []
        }
      end

      before do
        # Create a cached weather entry to avoid making real API calls
        WeatherCache.create!(
          address: valid_address.downcase,
          location: '40.7128,-74.0060',
          data: weather_data.to_json
        )
      end

      it 'redirects to index with address parameter when data is available' do
        post :forecast, params: { address: valid_address }
        expect(response).to redirect_to(weather_path(address: valid_address))
      end

      it 'redirects to index with weather data' do
        post :forecast, params: { address: valid_address }
        # The action should redirect to the index page with the address parameter
        expect(response).to redirect_to(weather_path(address: valid_address))
      end

      it 'redirects with the address parameter' do
        post :forecast, params: { address: valid_address }
        expect(response).to redirect_to(weather_path(address: valid_address))
      end
    end

    context 'when address is not provided' do
      it 'sets an error flash message' do
        post :forecast, params: { address: '' }
        expect(flash[:error]).to match(/Please enter an address or zip code/)
      end

      it 'redirects to index' do
        post :forecast, params: { address: '' }
        expect(response).to redirect_to(weather_path)
      end
    end

    context 'when weather service raises an error' do
      before do
        allow_any_instance_of(WeatherService).to receive(:get_forecast).and_raise(StandardError, 'Test error')
      end

      it 'sets an error flash message' do
        post :forecast, params: { address: 'Test Address' }
        expect(flash[:error]).to match(/An error occurred while retrieving weather data/)
      end
    end
  end

  describe 'routing' do
    it 'routes GET /weather to #index' do
      expect(get: '/weather').to route_to(controller: 'weather', action: 'index')
    end

    it 'routes POST /weather/forecast to #forecast' do
      expect(post: '/weather/forecast').to route_to(controller: 'weather', action: 'forecast')
    end
  end
end
