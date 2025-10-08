require 'rails_helper'

RSpec.describe WeatherCache, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:address) }
    it { should validate_presence_of(:location) }
    it { should validate_presence_of(:data) }
  end

  describe 'scopes' do
    let!(:fresh_cache) { create(:weather_cache, created_at: 15.minutes.ago) }
    let!(:expired_cache) { create(:weather_cache, created_at: 45.minutes.ago) }

    describe '.fresh' do
      it 'returns caches created within the last 30 minutes' do
        expect(WeatherCache.fresh).to include(fresh_cache)
        expect(WeatherCache.fresh).not_to include(expired_cache)
      end
    end

    describe '.expired' do
      it 'returns caches created more than 30 minutes ago' do
        expect(WeatherCache.expired).to include(expired_cache)
        expect(WeatherCache.expired).not_to include(fresh_cache)
      end
    end
  end
end
