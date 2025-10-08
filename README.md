# Weather Forecast Application

A Ruby on Rails application that provides weather forecasts based on user-provided addresses or ZIP codes. The application leverages the OpenWeatherMap API with Redis caching for improved performance and reduced API usage.

## Features

- **Real-time Weather Data**: Fetches current weather conditions and forecasts using OpenWeatherMap API
- **Address & ZIP Code Support**: Supports both city names and ZIP codes for weather lookup
- **Caching**: Implements Redis-based caching with 30-minute expiration to reduce API calls
- **International Support**: Handles various international addresses and ZIP code formats
- **Modern UI**: Built with Tailwind CSS and Hotwire (Turbo/Stimulus) for responsive user experience
- **Turbo Streams**: Provides dynamic updates without full page reloads
- **PWA Ready**: Includes service worker and manifest for Progressive Web App capabilities

## Technology Stack

- **Ruby on Rails 8.0.3**: Modern web application framework
- **Ruby 3.4.6**: Programming language
- **PostgreSQL**: Database management system
- **Redis**: Caching and session storage
- **Tailwind CSS**: Utility-first CSS framework
- **Hotwire (Turbo & Stimulus)**: HTML-over-the-wire framework
- **Docker**: Containerization for deployment
- **Fly.io**: Cloud deployment platform

## System Dependencies

- Ruby 3.4.6
- PostgreSQL 12+
- Redis 6+
- Node.js 18+ (for asset compilation)
- Yarn (for JavaScript dependencies)

## Configuration

1. **Environment Variables**:
   ```bash
   cp example.env .env
   ```
   - Set `OPENWEATHER_API_KEY` with your OpenWeatherMap API key
   - Configure database credentials if needed
   - Set Redis connection details (default: localhost:6379)

2. **Rails Credentials** (alternative to environment variables):
   ```bash
   EDITOR="code --wait" bin/rails credentials:edit
   ```
   Add the following:
   ```yaml
   openweather_api_key: your_api_key_here
   ```

## Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd maplight-exercise-app
   ```

2. **Install dependencies**:
   ```bash
   bundle install
   yarn install
   ```

3. **Database setup**:
   ```bash
   rails db:create
   rails db:migrate
   ```

4. **Start services**:
   ```bash
   # Start Redis and PostgreSQL services
   # On macOS with Homebrew:
   brew services start redis
   brew services start postgresql

   # Start the Rails server
   bin/dev  # Uses Procfile.dev which includes all necessary services
   # Or separately:
   # redis-server
   # rails server
   ```

5. **Access the application**:
   Open [http://localhost:4000](http://localhost:4000) in your browser

## Running Tests

Execute the complete test suite with:
```bash
bundle exec rspec
```

For specific test types:
```bash
# Run only model tests
bundle exec rspec spec/models/

# Run only controller tests
bundle exec rspec spec/controllers/

# Run only service tests
bundle exec rspec spec/services/
```

## Development

The application follows Rails development best practices and includes:

- RSpec for testing
- RuboCop for code style enforcement
- Stimulus for client-side JavaScript
- Tailwind CSS for styling
- Turbo for dynamic page updates

## Deployment

### Fly.io Deployment
The application includes `fly.toml` for easy deployment to Fly.io:

1. Install the Fly CLI: https://fly.io/docs/getting-started/installing-flyctl/
2. Sign in: `fly auth login`
3. Launch the app: `fly launch`
4. Deploy: `fly deploy`

### Docker Deployment
The application includes a production-ready Dockerfile:

```bash
# Build the image
docker build -t weather-app .

# Run the container (requires Redis and PostgreSQL)
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY=<your_master_key> \
  -e DATABASE_URL=<your_db_url> \
  -e REDIS_URL=<your_redis_url> \
  -e OPENWEATHER_API_KEY=<your_api_key> \
  --name weather-app weather-app
```

## Architecture

### Key Components

- **WeatherService**: Core service that handles API communication with OpenWeatherMap
- **WeatherController**: Handles HTTP requests and responses for weather data
- **Redis Cache**: Stores weather data for 30 minutes to reduce API calls
- **Geocoding**: Converts addresses and ZIP codes to coordinates for weather lookup

### Caching Strategy

- Weather data is cached for 30 minutes after retrieval
- Cache keys include both normalized address and coordinates
- In case of Redis connectivity issues, the application gracefully continues operation

## API Integration

The application uses the OpenWeatherMap API for:
- Current weather conditions
- 5-day weather forecasts
- Address geocoding to coordinates

The service handles both direct address lookup and ZIP code lookups, with special handling for international ZIP codes.

## Performance Considerations

- Caching reduces API call frequency and improves response times
- Database queries are optimized with appropriate indexing
- Assets are precompiled and served efficiently
- Turbo provides SPA-like experience without heavy JavaScript

## Maintenance

### Clearing Cache
The UI includes a cache clearing feature, or you can clear cache via Rails console:
```ruby
Rails.cache.clear
```

### Monitoring
The application includes a health check endpoint at `/up` that returns 200 if the app is functioning properly.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for your changes
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
