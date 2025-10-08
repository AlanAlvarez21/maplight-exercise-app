class WeatherCache < ActiveRecord::Base
  validates :address, presence: true
  validates :location, presence: true
  validates :data, presence: true

  scope :fresh, -> { where('created_at > ?', 30.minutes.ago) }
  scope :expired, -> { where('created_at <= ?', 30.minutes.ago) }
end