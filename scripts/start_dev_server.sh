#!/bin/bash
# Development Server Startup Script
# Starts Puma web server and Sidekiq background workers

echo "🚀 Starting Meme Explorer Development Server..."

# Kill any existing Puma/Sidekiq processes
echo "🛑 Stopping any running instances..."
pkill -f puma
pkill -f sidekiq
sleep 2

# Create log directory if it doesn't exist
mkdir -p log

# Start Sidekiq in background
echo "📦 Starting Sidekiq workers..."
bundle exec sidekiq -r ./app.rb -C config/sidekiq.yml > log/sidekiq.log 2>&1 &
SIDEKIQ_PID=$!
echo "   Sidekiq started (PID: $SIDEKIQ_PID)"

# Wait a moment for Sidekiq to initialize
sleep 2

# Start Puma web server
echo "🌐 Starting Puma web server..."
bundle exec rackup config.ru -o 0.0.0.0 -p 8080 &
PUMA_PID=$!
echo "   Puma started (PID: $PUMA_PID)"

sleep 3

echo ""
echo "✅ Server started successfully!"
echo ""
echo "📍 Application URLs:"
echo "   Local:   http://localhost:8080"
echo "   Network: http://0.0.0.0:8080"
echo ""
echo "📊 Monitoring:"
echo "   Web logs:     tail -f log/puma.log"
echo "   Worker logs:  tail -f log/sidekiq.log"
echo "   Session logs: tail -f log/sidekiq.log | grep SESSION"
echo ""
echo "🛑 To stop servers:"
echo "   kill $PUMA_PID $SIDEKIQ_PID"
echo "   or run: pkill -f puma && pkill -f sidekiq"
echo ""
echo "🔍 View session cleanup in action:"
echo "   tail -f log/sidekiq.log | grep -E '(SESSION|🧹|🧟|💤)'"
