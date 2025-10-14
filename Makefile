# Varnish Cache for cPanel/WHM - Optimized Installer
# Version 2.0 - Unified Installation System

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
NC=\033[0m

.DEFAULT_GOAL := help

help:
	@echo "🚀 Varnish Cache for cPanel/WHM v2.0 - Available Commands:"
	@echo ""
	@echo "📦 INSTALLATION (Unified Installer):"
	@echo "  make install          - Complete installation with LiteSpeed-level optimizations"
	@echo "  make install-cpanel   - Configure existing Varnish for cPanel only"
	@echo "  make install-plugin   - Install WHM management plugin only"
	@echo "  make optimize         - Apply performance optimizations to existing installation"
	@echo ""
	@echo "🔧 MANAGEMENT:"
	@echo "  make validate         - Validate current installation"
	@echo "  make status           - Show detailed installation status and recommendations"
	@echo "  make setup-cron       - Setup automatic SSL certificate updates"
	@echo "  make uninstall        - Remove Varnish and restore original configuration"
	@echo ""
	@echo "🧹 MAINTENANCE:"
	@echo "  make clean            - Clean temporary files"
	@echo "  make test             - Run performance tests"
	@echo ""
	@echo "💡 EASY ONE-LINER INSTALLATION:"
	@echo "  curl -sSL https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/unified-installer.sh | sudo bash"
	@echo ""
	@echo "🎮 WHM Plugin Access:"
	@echo "  URL: https://your-server:2087/cgi/varnish/whm_varnish_manager.cgi"
	@echo "  Menu: WHM → System → Varnish Cache Manager"
	@echo ""
	@echo "📊 Performance Features:"
	@echo "  • LiteSpeed-level speed optimization"
	@echo "  • Advanced VCL with intelligent caching"
	@echo "  • Real-time performance monitoring"
	@echo "  • Auto-scaling based on server specs"
	@echo ""

# Main installation using unified installer
install:
	@echo "🚀 Starting unified installation..."
	@chmod +x unified-installer.sh
	@./unified-installer.sh --auto

# Configure existing Varnish for cPanel
install-cpanel:
	@echo "🔧 Configuring Varnish for cPanel..."
	@chmod +x configure_varnish_cpanel.sh
	@./configure_varnish_cpanel.sh

# Install WHM plugin only
install-plugin:
	@echo "🎮 Installing WHM plugin..."
	@chmod +x unified-installer.sh
	@echo "4" | ./unified-installer.sh

# Apply performance optimizations
optimize:
	@echo "⚡ Applying performance optimizations..."
	@chmod +x optimize-performance.sh
	@./optimize-performance.sh

# Validate installation
validate:
	@echo "✅ Validating installation..."
	@chmod +x validate_varnish_config.sh
	@./validate_varnish_config.sh

# Check installation status
status:
	@echo "📊 Running installation status check..."
	@chmod +x check-status.sh
	@./check-status.sh

# Setup automatic certificate updates
setup-cron:
	@echo "⏰ Setting up automatic certificate updates..."
	@chmod +x update_hitch_certs.sh
	@crontab -l > mycron 2>/dev/null || true
	@if ! grep -q "update_hitch_certs.sh" mycron; then \
		echo "0 3 * * 0 $(PWD)/update_hitch_certs.sh" >> mycron; \
		crontab mycron; \
		echo "✅ Cron job added for certificate updates"; \
	else \
		echo "ℹ️  Cron job already exists"; \
	fi
	@rm -f mycron

# Uninstall Varnish
uninstall:
	@echo "🗑️ Starting uninstallation..."
	@chmod +x easy-uninstall.sh
	@./easy-uninstall.sh

# Performance testing
test:
	@echo "🧪 Running performance tests..."
	@if command -v curl &> /dev/null; then \
		echo "Testing HTTP response..."; \
		curl -s -o /dev/null -w "Response Code: %{http_code}\nTime Total: %{time_total}s\nSize Downloaded: %{size_download} bytes\n" http://localhost/; \
		echo "Testing cache headers..."; \
		curl -s -I http://localhost/ | grep -i "x-cache\|x-served-by\|x-varnish" || echo "No cache headers found"; \
	else \
		echo "curl not available for testing"; \
	fi

# Clean temporary files
clean:
	@echo "🧹 Cleaning up temporary files..."
	@rm -f mycron *.log *.tmp
	@rm -rf /tmp/varnish-*
	@echo "✅ Cleanup completed"

.PHONY: help install install-cpanel install-plugin optimize validate status setup-cron uninstall test clean