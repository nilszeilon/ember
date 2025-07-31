#!/bin/bash

# Emberchat Deployment Script
# This script helps you deploy Emberchat using Kamal

set -e

echo "🔥 Emberchat Kamal Deployment Helper"
echo "======================================"

# Check if kamal is installed
if ! command -v kamal &> /dev/null; then
    echo "❌ Kamal is not installed. Installing now..."
    gem install kamal
fi

echo "✅ Kamal is installed"

# Check if config/deploy.yml exists
if [ ! -f "config/deploy.yml" ]; then
    echo "❌ config/deploy.yml not found. Please create it from the template."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please create it from .env.example"
    echo "   cp .env.example .env"
    echo "   Then edit .env with your configuration"
    exit 1
fi

# Load environment variables
source .env

# Check required environment variables
required_vars=("SECRET_KEY_BASE" "PHX_HOST")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set in .env"
        exit 1
    fi
done

echo "✅ Environment variables configured"

# Deployment command selection
case "${1:-help}" in
    "setup")
        echo "🚀 Setting up deployment infrastructure..."
        kamal setup
        ;;
    "deploy")
        echo "🚀 Deploying application..."
        kamal deploy
        ;;
    "restart")
        echo "🔄 Restarting application..."
        kamal app restart
        ;;
    "logs")
        echo "📋 Showing application logs..."
        kamal app logs --follow
        ;;
    "console")
        echo "💻 Opening remote console..."
        kamal app exec --interactive --reuse "bin/emberchat remote"
        ;;
    "rollback")
        echo "⏪ Rolling back to previous version..."
        kamal rollback
        ;;
    "status")
        echo "📊 Checking deployment status..."
        kamal details
        ;;
    "remove")
        echo "🗑️  Removing deployment (WARNING: This will delete everything!)..."
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            kamal remove
        else
            echo "Cancelled."
        fi
        ;;
    *)
        echo "Usage: $0 {setup|deploy|restart|logs|console|rollback|status|remove}"
        echo ""
        echo "Commands:"
        echo "  setup    - Initial deployment setup (run once)"
        echo "  deploy   - Deploy the application"
        echo "  restart  - Restart the application"
        echo "  logs     - Show application logs"
        echo "  console  - Open remote Elixir console"
        echo "  rollback - Rollback to previous version"
        echo "  status   - Show deployment status"
        echo "  remove   - Remove entire deployment"
        echo ""
        echo "Before deploying, make sure to:"
        echo "1. Copy .env.example to .env and configure it"
        echo "2. Update config/deploy.yml with your server details"
        echo "3. Ensure your VPS is accessible via SSH"
        ;;
esac