class WeatherController < ApplicationController
  def index
    @address = params[:address]
    if @address.present?
      begin
        @weather_result = WeatherService.new.get_forecast(@address)
        @cached = @weather_result[:cached]
        @cached_at = @weather_result[:cached_at]  # Capture cache timestamp if available
        @weather_data = @weather_result[:data]

        unless @weather_data
          # Check if the geocoding failed because the ZIP code doesn't exist
          coordinates = WeatherService.new.send(:geocode_address, @address)
          if coordinates.is_a?(Hash) && coordinates[:error] == "not_found"
            flash.now[:error] = "ZIP code '#{@address}' does not exist. Please enter a valid ZIP code."
          else
            flash.now[:error] = "Could not retrieve weather data for '#{@address}'. Please try using a more specific format like 'City, State' or 'City, Country'. For ZIP codes, ensure they are valid for the US."
          end
        end
      rescue => e
        Rails.logger.error "Error retrieving weather forecast: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        flash.now[:error] = "An error occurred while retrieving weather data: #{e.message}"
      end
    end
  end

  def forecast
    address = params[:address]

    if address.present?
      begin
        weather_result = WeatherService.new.get_forecast(address)
        @cached = weather_result[:cached]
        @cached_at = weather_result[:cached_at]  # Capture cache timestamp if available
        @weather_data = weather_result[:data]
        @address = address

        # Check if the geocoding failed because the ZIP code doesn't exist
        unless @weather_data
          coordinates = WeatherService.new.send(:geocode_address, address)
          if coordinates.is_a?(Hash) && coordinates[:error] == "not_found"
            flash.now[:error] = "ZIP code '#{address}' does not exist. Please enter a valid ZIP code."
          end
        end

        respond_to do |format|
          format.html { 
            # For regular HTML requests, redirect to index with address parameter
            redirect_to weather_path(address: address)
          }
          format.turbo_stream {
            # For Turbo requests, render only the weather data partial
            render turbo_stream: turbo_stream.replace("weather_data_container", 
              render_to_string(partial: "weather_data", 
                               locals: { weather_data: @weather_data, 
                                         address: @address, 
                                         cached: @cached, 
                                         cached_at: @cached_at }))
          }
        end
      rescue => e
        Rails.logger.error "Error retrieving weather forecast: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        flash.now[:error] = "An error occurred while retrieving weather data: #{e.message}"
        
        respond_to do |format|
          format.html { 
            # Render the index view without data so the user can try again
            render :index
          }
          format.turbo_stream {
            # For Turbo requests, render only the weather data partial with error state
            render turbo_stream: turbo_stream.replace("weather_data_container", 
              render_to_string(partial: "weather_data", 
                               locals: { weather_data: nil, 
                                         address: address, 
                                         cached: nil, 
                                         cached_at: nil }))
          }
        end
      end
    else
      # When no address is provided, set an error flash message and redirect to index
      flash[:error] = "Please enter an address or zip code"
      redirect_to weather_path
    end
  end

  def clear_cache
    address = params[:address]
    
    if address.present?
      begin
        # Get the weather service instance to access its private methods
        weather_service = WeatherService.new
        
        # Access the private geocode_address method using send
        coordinates = weather_service.send(:geocode_address, address)
        
        if coordinates
          # Generate cache key using the same pattern as WeatherService
          normalized_address = address.strip.downcase
          cache_key = "weather_cache:#{normalized_address}:#{coordinates[:lat]},#{coordinates[:lon]}"
          
          # Delete the specific cache entry
          Rails.cache.delete(cache_key)
          
          respond_to do |format|
            format.html { 
              redirect_to weather_forecast_path(address: address), notice: "Cache cleared for #{address}. Fetching fresh data..."
            }
            format.turbo_stream { 
              # Fetch fresh weather data after clearing cache
              fresh_weather_result = weather_service.get_forecast(address)
              
              # Prepare the weather content with fresh data
              fresh_weather_data = fresh_weather_result[:data]
              fresh_cached = fresh_weather_result[:cached]
              fresh_cached_at = fresh_weather_result[:cached_at]
              
              # Send a Turbo stream response with the fresh data
              success_html = "<div class='bg-green-50 border-l-4 border-green-500 p-4 rounded-lg mb-6'>" +
                             "<div class='flex'>" +
                             "<div class='flex-shrink-0'>" +
                             "<svg class='h-5 w-5 text-green-500' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='currentColor'>" +
                             "<path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z' clip-rule='evenodd' /></svg>" +
                             "</div>" +
                             "<div class='ml-3'>" +
                             "<p class='text-sm text-green-700'>Cache cleared for #{address}. Showing fresh weather data.</p>" +
                             "</div>" +
                             "</div>" +
                             "</div>"
              
              # Use Turbo stream to update the weather content with fresh data
              render turbo_stream: [
                turbo_stream.prepend("weather_data_container", success_html.html_safe),
                turbo_stream.replace("weather_data_container", 
                                   render_to_string(partial: "weather_data", 
                                                    locals: { 
                                                      weather_data: fresh_weather_data, 
                                                      address: address, 
                                                      cached: fresh_cached, 
                                                      cached_at: fresh_cached_at 
                                                    }))
              ]
            }
          end
        else
          respond_to do |format|
            format.html { 
              redirect_to root_path, alert: "Could not determine coordinates for #{address}"
            }
            format.turbo_stream {
              error_html = "<div class='bg-red-50 border-l-4 border-red-500 p-4 rounded-lg mt-6'>" +
                           "<div class='flex'>" +
                           "<div class='flex-shrink-0'>" +
                           "<svg class='h-5 w-5 text-red-500' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='currentColor'>" +
                           "<path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z' clip-rule='evenodd' /></svg>" +
                           "</div>" +
                           "<div class='ml-3'>" +
                           "<p class='text-sm text-red-700'>Could not determine coordinates for #{address}</p>" +
                           "</div>" +
                           "</div>" +
                           "</div>"
              render turbo_stream: turbo_stream.replace("weather_data_container", error_html.html_safe)
            }
          end
        end
      rescue => e
        Rails.logger.error "Error clearing cache for address #{address}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        respond_to do |format|
          format.html { 
            redirect_to root_path, alert: "Error clearing cache: #{e.message}"
          }
          format.turbo_stream {
            error_html = "<div class='bg-red-50 border-l-4 border-red-500 p-4 rounded-lg mt-6'>" +
                         "<div class='flex'>" +
                         "<div class='flex-shrink-0'>" +
                         "<svg class='h-5 w-5 text-red-500' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='currentColor'>" +
                         "<path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z' clip-rule='evenodd' /></svg>" +
                         "</div>" +
                         "<div class='ml-3'>" +
                         "<p class='text-sm text-red-700'>Error clearing cache: #{e.message}</p>" +
                         "</div>" +
                         "</div>" +
                         "</div>"
            render turbo_stream: turbo_stream.replace("weather_content", error_html.html_safe)
          }
        end
      end
    else
      # If no address provided, clear all cache as fallback
      Rails.cache.clear
      
      respond_to do |format|
        format.html { 
          redirect_to root_path, notice: "Cache cleared successfully"
        }
        format.turbo_stream { 
          # Send a Turbo stream response to update the UI without full reload
          # Show a success message and replace the weather content with an empty state
          success_html = "<div class='bg-green-50 border-l-4 border-green-500 p-4 rounded-lg mb-6'>" +
                         "<div class='flex'>" +
                         "<div class='flex-shrink-0'>" +
                         "<svg class='h-5 w-5 text-green-500' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='currentColor'>" +
                         "<path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z' clip-rule='evenodd' /></svg>" +
                         "</div>" +
                         "<div class='ml-3'>" +
                         "<p class='text-sm text-green-700'>Cache cleared successfully</p>" +
                         "</div>" +
                         "</div>" +
                         "</div>"
          
          # Use Turbo stream to show success message and update weather content
          render turbo_stream: [
            turbo_stream.prepend("weather_data_container", success_html.html_safe),
            turbo_stream.replace("weather_data_container", 
                                 render_to_string(partial: "weather_data", 
                                                  locals: { weather_data: nil, address: nil, cached: nil, cached_at: nil }))
          ]
        }
      rescue => e
        Rails.logger.error "Error clearing cache: #{e.message}"
        respond_to do |format|
          format.html { 
            redirect_to root_path, alert: "Error clearing cache: #{e.message}"
          }
          format.turbo_stream {
            error_html = "<div class='bg-red-50 border-l-4 border-red-500 p-4 rounded-lg mt-6'>" +
                         "<div class='flex'>" +
                         "<div class='flex-shrink-0'>" +
                         "<svg class='h-5 w-5 text-red-500' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='currentColor'>" +
                         "<path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z' clip-rule='evenodd' /></svg>" +
                         "</div>" +
                         "<div class='ml-3'>" +
                         "<p class='text-sm text-red-700'>Error clearing cache: #{e.message}</p>" +
                         "</div>" +
                         "</div>" +
                         "</div>"
            render turbo_stream: turbo_stream.replace("weather_data_container", error_html.html_safe)
          }
        end
      end
    end
  end
end