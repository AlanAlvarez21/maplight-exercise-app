require 'rails_helper'

RSpec.describe WeatherData::CurrentWeather, type: :model do
  let(:raw_weather_data) do
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

  subject { WeatherData::CurrentWeather.new(raw_weather_data) }

  describe '#location' do
    it 'returns the location' do
      expect(subject.location).to eq('New York')
    end
  end

  describe '#country' do
    it 'returns the country' do
      expect(subject.country).to eq('US')
    end
  end

  describe '#current_temperature' do
    it 'returns the current temperature' do
      expect(subject.current_temperature).to eq(72)
    end
  end

  describe '#feels_like' do
    it 'returns the feels like temperature' do
      expect(subject.feels_like).to eq(70)
    end
  end

  describe '#high_temperature' do
    it 'returns the high temperature' do
      expect(subject.high_temperature).to eq(75)
    end
  end

  describe '#low_temperature' do
    it 'returns the low temperature' do
      expect(subject.low_temperature).to eq(68)
    end
  end

  describe '#humidity' do
    it 'returns the humidity' do
      expect(subject.humidity).to eq(65)
    end
  end

  describe '#pressure' do
    it 'returns the pressure' do
      expect(subject.pressure).to eq(1013)
    end
  end

  describe '#description' do
    it 'returns the description' do
      expect(subject.description).to eq('clear sky')
    end
  end

  describe '#icon_url' do
    it 'returns the icon URL' do
      expect(subject.icon_url).to eq('https://openweathermap.org/img/w/01d.png')
    end
  end

  describe '#wind_speed' do
    it 'returns the wind speed' do
      expect(subject.wind_speed).to eq(5.5)
    end
  end

  describe '#wind_deg' do
    it 'returns the wind direction' do
      expect(subject.wind_deg).to eq(180)
    end
  end

  describe '#hourly_forecast' do
    it 'returns an array of HourlyForecast objects' do
      hourly = subject.hourly_forecast.first
      expect(hourly).to be_a(WeatherData::HourlyForecast)
      expect(hourly.time).to eq('12:00 PM')
      expect(hourly.temp).to eq(72)
      expect(hourly.condition).to eq('clear sky')
      expect(hourly.icon).to eq('01d')
    end
  end

  describe '#forecast' do
    it 'returns an array of DailyForecast objects' do
      daily = subject.forecast.first
      expect(daily).to be_a(WeatherData::DailyForecast)
      expect(daily.day).to eq('Monday')
      expect(daily.date).to eq('10/10')
      expect(daily.high).to eq(75)
      expect(daily.low).to eq(68)
      expect(daily.condition).to eq('sunny')
      expect(daily.icon).to eq('01d')
    end
  end

  describe '#to_h' do
    it 'returns the original hash data' do
      expect(subject.to_h).to eq(raw_weather_data)
    end
  end
end

RSpec.describe WeatherData::HourlyForecast, type: :model do
  let(:raw_hourly_data) do
    {
      time: '12:00 PM',
      temp: 72,
      condition: 'clear sky',
      icon: '01d'
    }
  end

  subject { WeatherData::HourlyForecast.new(raw_hourly_data) }

  describe '#time' do
    it 'returns the time' do
      expect(subject.time).to eq('12:00 PM')
    end
  end

  describe '#temp' do
    it 'returns the temperature' do
      expect(subject.temp).to eq(72)
    end
  end

  describe '#condition' do
    it 'returns the condition' do
      expect(subject.condition).to eq('clear sky')
    end
  end

  describe '#icon' do
    it 'returns the icon' do
      expect(subject.icon).to eq('01d')
    end
  end
end

RSpec.describe WeatherData::DailyForecast, type: :model do
  let(:raw_daily_data) do
    {
      day: 'Monday',
      date: '10/10',
      high: 75,
      low: 68,
      condition: 'sunny',
      icon: '01d'
    }
  end

  subject { WeatherData::DailyForecast.new(raw_daily_data) }

  describe '#day' do
    it 'returns the day' do
      expect(subject.day).to eq('Monday')
    end
  end

  describe '#date' do
    it 'returns the date' do
      expect(subject.date).to eq('10/10')
    end
  end

  describe '#high' do
    it 'returns the high temperature' do
      expect(subject.high).to eq(75)
    end
  end

  describe '#low' do
    it 'returns the low temperature' do
      expect(subject.low).to eq(68)
    end
  end

  describe '#condition' do
    it 'returns the condition' do
      expect(subject.condition).to eq('sunny')
    end
  end

  describe '#icon' do
    it 'returns the icon' do
      expect(subject.icon).to eq('01d')
    end
  end
end