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
          flash.now[:error] = "Could not retrieve weather data for '#{@address}'. Please try using a more specific format like 'City, State' or 'City, Country'. For ZIP codes, ensure they are valid for the US."
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

        respond_to do |format|
          format.html { 
            # For regular HTML requests, render the index template
            render :index
          }
          format.turbo_stream {
            # For Turbo requests, render the weather content partial
            render turbo_stream: turbo_stream.replace("weather_content", 
              render_to_string(partial: "weather_content", 
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
            # For Turbo requests, render the weather content partial with error state
            render turbo_stream: turbo_stream.replace("weather_content", 
              render_to_string(partial: "weather_content", 
                               locals: { weather_data: nil, 
                                         address: address, 
                                         cached: nil, 
                                         cached_at: nil }))
          }
        end
      end
    else
      flash.now[:error] = "Please enter an address or zip code."
      
      respond_to do |format|
        format.html { 
          render :index
        }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("weather_content", 
            render_to_string(partial: "weather_content", 
                             locals: { weather_data: nil, 
                                       address: nil, 
                                       cached: nil, 
                                       cached_at: nil }))
        }
      end
    end
  end

  def clear_cache
    Rails.cache.clear
    
    respond_to do |format|
      format.html { 
        redirect_to root_path, notice: "Cache cleared successfully"
      }
      format.turbo_stream { 
        # Send a Turbo stream response to update the UI without full reload
        # This will replace the weather content with an empty state
        render turbo_stream: turbo_stream.replace("weather_content", 
          render_to_string(partial: "weather_content", 
                           locals: { weather_data: nil, address: nil, cached: nil, cached_at: nil }))
      }
    end
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
        render turbo_stream: turbo_stream.replace("weather_content", error_html.html_safe)
      }
    end
  end
end