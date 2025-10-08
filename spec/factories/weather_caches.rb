FactoryBot.define do
  factory :weather_cache do
    sequence(:address) { |n| "Location #{n}, City #{n}" }
    location { '40.7128,-74.0060' }
    data { { temperature: 72, description: 'sunny' }.to_json }
  end
end
