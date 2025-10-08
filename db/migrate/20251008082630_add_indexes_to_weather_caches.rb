class AddIndexesToWeatherCaches < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for faster lookups
    add_index :weather_caches, :address
    add_index :weather_caches, :location
    add_index :weather_caches, [:address, :location]  # Composite index for queries using both
    
    # Index for the created_at column to optimize the 'fresh' scope
    add_index :weather_caches, :created_at
  end
end
