class CreateWeatherCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :weather_caches do |t|
      t.string :address
      t.string :location
      t.text :data

      t.timestamps
    end
  end
end
