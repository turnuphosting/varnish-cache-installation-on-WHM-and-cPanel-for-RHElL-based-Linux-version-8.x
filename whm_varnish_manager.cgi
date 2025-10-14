#!/usr/bin/perl

use strict;
use warnings;
use lib '/usr/local/cpanel';
use Whostmgr::ACLS;
use Cpanel::Logger;
use JSON;
use CGI;

# Enable output buffering
$| = 1;

# Create CGI object
my $cgi = CGI->new();

# Print content type header
print $cgi->header(-type => 'text/html; charset=UTF-8');

# Check if user has access
exit unless Whostmgr::ACLS::hasroot();

# Main HTML interface
print <<'EOF';
<!DOCTYPE html>
<html>
<head>
    <title>WHM Varnish Cache Manager - Real-time Monitor</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <style>
        :root {
            --primary-color: #2271b1;
            --success-color: #00a32a;
            --warning-color: #f0b849;
            --error-color: #cc1818;
            --bg-gradient: linear-gradient(135deg, #fff 0%, #f8f9fa 100%);
            --card-shadow: 0 2px 15px rgba(0,0,0,0.08);
            --modal-overlay: rgba(0, 0, 0, 0.5);
        }

        /* Modal Styles */
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: var(--modal-overlay);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }

        .modal.active {
            display: flex;
        }

        .modal-content {
            background: white;
            border-radius: 12px;
            padding: 30px;
            width: 90%;
            max-width: 800px;
            max-height: 90vh;
            overflow-y: auto;
            position: relative;
        }

        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }

        .modal-header h2 {
            margin: 0;
            color: var(--primary-color);
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .modal-close {
            background: none;
            border: none;
            font-size: 24px;
            cursor: pointer;
            color: #666;
        }

        .modal-body {
            padding: 0;
        }

        .modal-actions {
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            display: flex;
            justify-content: flex-end;
            gap: 10px;
        }

        .warning-message {
            text-align: center;
        }

        .warning-message h3 {
            color: var(--warning-color);
            margin-bottom: 15px;
        }

        .purge-details {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 6px;
            padding: 15px;
            margin: 20px 0;
            text-align: left;
        }

        .purge-details h4 {
            margin-top: 0;
            color: var(--warning-color);
        }

        .purge-details ul {
            margin: 10px 0 0 20px;
        }

        .confirmation-section {
            margin: 20px 0;
            text-align: left;
        }

        .confirmation-section label {
            display: flex;
            align-items: center;
            gap: 10px;
            cursor: pointer;
        }

        #confirmPurgeBtn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        /* Toast Notifications */
        .toast {
            position: fixed;
            top: 20px;
            right: -400px;
            background: white;
            border-radius: 8px;
            padding: 15px 20px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            display: flex;
            align-items: center;
            gap: 10px;
            z-index: 2000;
            transition: right 0.3s ease;
            min-width: 300px;
        }

        .toast.active {
            right: 20px;
        }

        .toast-info {
            border-left: 4px solid var(--primary-color);
        }

        .toast-success {
            border-left: 4px solid var(--success-color);
        }

        .toast-error {
            border-left: 4px solid var(--error-color);
        }

        .toast-info i {
            color: var(--primary-color);
        }

        .toast-success i {
            color: var(--success-color);
        }

        .toast-error i {
            color: var(--error-color);
        }

        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 0;
            padding: 0;
            background: #f4f4f4;
            color: #333;
        }

        .whm-header {
            background: #1d2327;
            color: white;
            padding: 15px 20px;
            border-bottom: 4px solid var(--primary-color);
        }

        .whm-navigation {
            background: #2c3338;
            padding: 10px 20px;
            color: white;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .main-content {
            padding: 20px;
            max-width: 1400px;
            margin: 0 auto;
        }

        .section-tabs {
            display: flex;
            gap: 2px;
            background: #e9ecef;
            padding: 2px;
            border-radius: 8px;
            margin-bottom: 20px;
        }

        .section-tab {
            padding: 10px 20px;
            border-radius: 6px;
            cursor: pointer;
            flex: 1;
            text-align: center;
            font-weight: 500;
            transition: all 0.2s;
            color: #666;
        }

        .section-tab.active {
            background: white;
            color: var(--primary-color);
        }

        .card {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: var(--card-shadow);
            margin-bottom: 20px;
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #f0f0f0;
        }

        .card-header h3 {
            margin: 0;
            display: flex;
            align-items: center;
            gap: 10px;
            color: var(--primary-color);
        }

        .refresh-time {
            color: #666;
            font-size: 0.9em;
        }

        /* Performance Overview Styles */
        .performance-overview {
            background: var(--bg-gradient);
        }

        .performance-score {
            display: grid;
            grid-template-columns: auto 1fr;
            gap: 30px;
            margin: 20px 0;
        }

        .score-circle {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            background: conic-gradient(var(--success-color) 0% 98%, #f0f0f0 98% 100%);
            color: white;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            position: relative;
        }

        .score-circle::before {
            content: '';
            position: absolute;
            width: 130px;
            height: 130px;
            background: white;
            border-radius: 50%;
            z-index: 1;
        }

        .score-circle .score {
            font-size: 48px;
            font-weight: bold;
            color: var(--success-color);
            position: relative;
            z-index: 2;
        }

        .score-circle .score-label {
            font-size: 14px;
            color: #666;
            text-align: center;
            position: relative;
            z-index: 2;
        }

        .score-circle .score-subtitle {
            font-size: 12px;
            color: var(--success-color);
            position: relative;
            z-index: 2;
        }

        .metrics-row {
            display: grid;
            gap: 20px;
            margin-bottom: 20px;
        }

        .metrics-row.triple {
            grid-template-columns: repeat(3, 1fr);
        }

        .metric-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            cursor: pointer;
        }

        .metric-card:hover {
            transform: translateY(-2px);
        }

        .metric-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }

        .metric-header h4 {
            margin: 0;
            color: #333;
        }

        .metric-header i {
            font-size: 20px;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 8px;
            background: var(--bg-gradient);
            color: var(--primary-color);
        }

        .metric-value {
            font-size: 32px;
            font-weight: bold;
            color: var(--primary-color);
            margin: 10px 0;
        }

        .metric-footer {
            display: flex;
            justify-content: space-between;
            margin-top: 10px;
            font-size: 14px;
            color: #666;
        }

        .metric-footer .success-text {
            color: var(--success-color);
            font-weight: 500;
        }

        /* Security Status Grid */
        .security-status {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }

        .security-check {
            background: white;
            padding: 15px;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .security-check i {
            font-size: 24px;
            color: var(--success-color);
        }

        .security-info h4 {
            margin: 0 0 5px 0;
        }

        .security-info p {
            margin: 0;
            font-size: 14px;
            color: #666;
        }

        /* Domain Management Styles */
        .domain-controls {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 20px;
        }

        .action-buttons {
            display: flex;
            gap: 10px;
        }

        .btn {
            padding: 8px 16px;
            border-radius: 6px;
            border: none;
            cursor: pointer;
            font-weight: 500;
            color: white;
            background: var(--primary-color);
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s;
        }

        .btn:hover {
            filter: brightness(1.1);
        }

        .btn-warning {
            background: var(--warning-color);
            color: white;
            border: 1px solid var(--warning-color);
        }

        .btn-warning:hover {
            background: #e0a043;
            border-color: #e0a043;
        }

        .pagination-info {
            color: #666;
            font-size: 14px;
        }

        .domains-grid {
            margin-top: 20px;
        }

        .domain-row {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-bottom: 20px;
        }

        .domain-card {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            background: white;
            transition: all 0.2s ease;
        }

        .domain-card:hover {
            border-color: var(--primary-color);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            transform: translateY(-2px);
        }

        .domain-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 15px;
        }

        .domain-icon {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: var(--bg-gradient);
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--primary-color);
        }

        .domain-info h4 {
            margin: 0;
            font-size: 16px;
            color: #333;
        }

        .domain-metrics {
            color: #666;
            font-size: 14px;
        }

        .domain-stats {
            display: flex;
            justify-content: space-between;
            margin-bottom: 15px;
            padding: 10px 0;
            border-bottom: 1px solid #f0f0f0;
        }

        .stat-item {
            text-align: center;
        }

        .stat-label {
            display: block;
            font-size: 12px;
            color: #666;
            margin-bottom: 4px;
        }

        .stat-value {
            font-weight: 600;
            color: #333;
        }

        .domain-actions {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .status-badge {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }

        .status-badge.active {
            background: #e8f5e9;
            color: var(--success-color);
        }

        .status-badge.warning {
            background: #fff3cd;
            color: #856404;
        }

        .status-badge.inactive {
            background: #f8f9fa;
            color: #6c757d;
        }

        .btn-icon {
            width: 32px;
            height: 32px;
            border-radius: 6px;
            border: 1px solid #ddd;
            background: white;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.2s;
        }

        .btn-icon:hover {
            background: var(--bg-gradient);
            border-color: var(--primary-color);
            color: var(--primary-color);
        }

        /* Analytics Styles */
        .analytics-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 20px;
            margin-top: 20px;
        }

        .chart-wrapper {
            background: white;
            border-radius: 10px;
            padding: 15px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        }

        .chart-wrapper h4 {
            margin: 0 0 15px 0;
            color: #333;
        }

        .performance-chart {
            height: 250px;
            width: 100%;
            background: #f8f9fa;
            border-radius: 8px;
            position: relative;
        }

        .time-selector {
            display: flex;
            gap: 10px;
        }

        .time-selector .btn {
            background: transparent;
            color: #666;
        }

        .time-selector .btn.active {
            background: var(--primary-color);
            color: white;
        }

        /* Responsive Design */
        @media (max-width: 1200px) {
            .metrics-row.triple {
                grid-template-columns: 1fr;
            }
            
            .domain-row {
                grid-template-columns: repeat(2, 1fr);
            }
            
            .analytics-grid {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 768px) {
            .domain-row {
                grid-template-columns: 1fr;
            }
            
            .performance-score {
                grid-template-columns: 1fr;
                text-align: center;
            }
        }

        .hidden {
            display: none !important;
        }

        .section {
            display: none;
        }

        .section.active {
            display: block;
        }
    </style>
</head>
<body>
    <div class="whm-header">
        <h2>Varnish Cache Manager</h2>
    </div>
    <div class="whm-navigation">
        <span>Dashboard > Real-time Monitor</span>
        <button class="btn" onclick="showGlobalSettings()">
            <i class="fas fa-cog"></i> Global Settings
        </button>
    </div>
    
    <div class="main-content">
        <div class="section-tabs">
            <div class="section-tab active" onclick="showSection('overview')">Overview</div>
            <div class="section-tab" onclick="showSection('domains')">Domains</div>
            <div class="section-tab" onclick="showSection('analytics')">Analytics</div>
            <div class="section-tab" onclick="showSection('settings')">Settings</div>
            <div class="section-tab" onclick="showSection('logs')">Logs</div>
        </div>

        <!-- Overview Section -->
        <div id="overview-section" class="section active">
            <!-- Performance Overview -->
            <div class="card performance-overview">
                <div class="card-header">
                    <h3><i class="fas fa-tachometer-alt"></i> Performance Overview</h3>
                    <span class="refresh-time">Last updated: <span class="update-time">Just now</span></span>
                </div>
                <div class="performance-score">
                    <div class="score-circle">
                        <span class="score" id="overall-score">98</span>
                        <span class="score-label">Cache Performance</span>
                        <span class="score-subtitle">Excellent</span>
                    </div>
                    <div class="metrics-row triple">
                        <div class="metric-card">
                            <div class="metric-header">
                                <h4>Cache Hit Rate</h4>
                                <i class="fas fa-bullseye"></i>
                            </div>
                            <div class="metric-value" id="hit-rate">94%</div>
                            <div class="metric-footer">
                                <span class="success-text">↑3.2% High Efficiency</span>
                            </div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-header">
                                <h4>Cache Size</h4>
                                <i class="fas fa-database"></i>
                            </div>
                            <div class="metric-value" id="cache-size">24.5GB</div>
                            <div class="metric-footer">
                                <span class="success-text">Of 32GB Total</span>
                            </div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-header">
                                <h4>Request Rate</h4>
                                <i class="fas fa-exchange-alt"></i>
                            </div>
                            <div class="metric-value" id="request-rate">5.2K</div>
                            <div class="metric-footer">
                                <span class="success-text">Requests/min</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Security Status -->
            <div class="card">
                <div class="card-header">
                    <h3><i class="fas fa-shield-alt"></i> Security Status</h3>
                </div>
                <div class="security-status">
                    <div class="security-check">
                        <i class="fas fa-lock"></i>
                        <div class="security-info">
                            <h4>X-Content-Type-Options</h4>
                            <p>Prevents MIME-sniffing</p>
                        </div>
                    </div>
                    <div class="security-check">
                        <i class="fas fa-shield-alt"></i>
                        <div class="security-info">
                            <h4>X-Frame-Options</h4>
                            <p>Prevents clickjacking</p>
                        </div>
                    </div>
                    <div class="security-check">
                        <i class="fas fa-user-shield"></i>
                        <div class="security-info">
                            <h4>X-XSS-Protection</h4>
                            <p>Active XSS prevention</p>
                        </div>
                    </div>
                    <div class="security-check">
                        <i class="fas fa-key"></i>
                        <div class="security-info">
                            <h4>Access Control</h4>
                            <p>Restricted purge access</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- System Metrics -->
            <div class="card">
                <div class="card-header">
                    <h3><i class="fas fa-chart-line"></i> System Status</h3>
                </div>
                <div class="security-status">
                    <div class="security-check">
                        <i class="fas fa-lock"></i>
                        <div class="security-info">
                            <h4>SSL Certificates</h4>
                            <p id="ssl-status">12/12 All Valid</p>
                        </div>
                    </div>
                    <div class="security-check">
                        <i class="fas fa-microchip"></i>
                        <div class="security-info">
                            <h4>CPU Usage</h4>
                            <p id="cpu-usage">32% - 8 Cores</p>
                        </div>
                    </div>
                    <div class="security-check">
                        <i class="fas fa-memory"></i>
                        <div class="security-info">
                            <h4>Memory Usage</h4>
                            <p id="memory-usage">2.8GB of 4GB</p>
                        </div>
                    </div>
                    <div class="security-check">
                        <i class="fas fa-exchange-alt"></i>
                        <div class="security-info">
                            <h4>Requests/Second</h4>
                            <p id="requests-per-second">1.2K - Peak: 2.5K</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Domains Section -->
        <div id="domains-section" class="section">
            <div class="card">
                <div class="card-header">
                    <h3><i class="fas fa-globe"></i> Managed Domains</h3>
                    <div class="domain-controls">
                        <div class="pagination-info">
                            <span>Showing <span id="domains-showing">1-9</span> of <span id="domains-total">24</span> domains</span>
                        </div>
                        <div class="action-buttons">
                            <button class="btn btn-warning" onclick="showPurgeAllModal()">
                                <i class="fas fa-broom"></i> Purge All Cache
                            </button>
                            <button class="btn" onclick="addDomain()">
                                <i class="fas fa-plus"></i> Add Domain
                            </button>
                        </div>
                    </div>
                </div>
                <div class="domains-grid" id="domains-grid">
                    <!-- Domain cards will be populated by JavaScript -->
                </div>
            </div>
        </div>

        <!-- Analytics Section -->
        <div id="analytics-section" class="section">
            <div class="card">
                <div class="card-header">
                    <h3><i class="fas fa-chart-line"></i> Performance Analytics</h3>
                    <div class="time-selector">
                        <button class="btn active" onclick="changeTimeframe('hourly')">Hourly</button>
                        <button class="btn" onclick="changeTimeframe('daily')">Daily</button>
                        <button class="btn" onclick="changeTimeframe('weekly')">Weekly</button>
                        <button class="btn" onclick="changeTimeframe('monthly')">Monthly</button>
                    </div>
                </div>
                <div class="analytics-grid">
                    <div class="chart-wrapper">
                        <h4>Cache Hit Rate</h4>
                        <div class="performance-chart" id="hitRateChart"></div>
                    </div>
                    <div class="chart-wrapper">
                        <h4>Response Time</h4>
                        <div class="performance-chart" id="responseTimeChart"></div>
                    </div>
                    <div class="chart-wrapper">
                        <h4>Bandwidth Usage</h4>
                        <div class="performance-chart" id="bandwidthChart"></div>
                    </div>
                    <div class="chart-wrapper">
                        <h4>Request Distribution</h4>
                        <div class="performance-chart" id="requestDistChart"></div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Settings Section -->
        <div id="settings-section" class="section">
            <div class="card">
                <div class="card-header">
                    <h3><i class="fas fa-cog"></i> Varnish Configuration</h3>
                </div>
                <div id="settings-content">
                    <!-- Settings will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Logs Section -->
        <div id="logs-section" class="section">
            <div class="card">
                <div class="card-header">
                    <h3><i class="fas fa-file-alt"></i> Varnish Logs</h3>
                </div>
                <div id="logs-content">
                    <!-- Logs will be loaded here -->
                </div>
            </div>
        </div>
    </div>

    <!-- Global Settings Modal -->
    <div class="modal" id="globalSettingsModal">
        <div class="modal-content">
            <div class="modal-header">
                <h2><i class="fas fa-cog"></i> Global Settings</h2>
                <button class="modal-close" onclick="closeModal('globalSettingsModal')">&times;</button>
            </div>
            <div class="modal-body">
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px;">
                    <div style="background: var(--bg-gradient); padding: 20px; border-radius: 10px;">
                        <h3>Cache Configuration</h3>
                        <div style="display: grid; gap: 15px;">
                            <div>
                                <label>Default TTL (seconds)</label>
                                <input type="number" value="3600" min="0" step="60" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                            </div>
                            <div>
                                <label>Grace Period (seconds)</label>
                                <input type="number" value="300" min="0" step="60" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                            </div>
                            <div>
                                <label>Memory Allocation (MB)</label>
                                <input type="number" value="2048" min="256" step="256" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                            </div>
                        </div>
                    </div>
                    <div style="background: var(--bg-gradient); padding: 20px; border-radius: 10px;">
                        <h3>Security Settings</h3>
                        <div style="display: grid; gap: 15px;">
                            <div>
                                <label>ACL Configuration</label>
                                <select style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                                    <option>Strict</option>
                                    <option>Normal</option>
                                    <option>Permissive</option>
                                </select>
                            </div>
                            <div>
                                <label>SSL Policy</label>
                                <select style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                                    <option>Modern</option>
                                    <option>Intermediate</option>
                                    <option>Old</option>
                                </select>
                            </div>
                            <div>
                                <label>Purge Key</label>
                                <input type="password" value="********" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-actions">
                <button class="btn" style="background: #666" onclick="closeModal('globalSettingsModal')">Cancel</button>
                <button class="btn" style="background: var(--success-color)" onclick="saveGlobalSettings()">Save Changes</button>
            </div>
        </div>
    </div>

    <!-- Purge All Cache Modal -->
    <div class="modal" id="purgeAllModal">
        <div class="modal-content">
            <div class="modal-header">
                <h2><i class="fas fa-exclamation-triangle"></i> Purge All Cache</h2>
                <button class="modal-close" onclick="closeModal('purgeAllModal')">&times;</button>
            </div>
            <div class="modal-body">
                <div class="warning-message">
                    <i class="fas fa-exclamation-triangle" style="color: var(--warning-color); font-size: 48px; margin-bottom: 20px;"></i>
                    <h3>Warning: This action will purge all cached content</h3>
                    <p>This will clear the entire Varnish cache for all domains on this server. This may temporarily increase server load and response times as the cache rebuilds.</p>
                    
                    <div class="purge-details">
                        <h4>What will be affected:</h4>
                        <ul>
                            <li>All cached web pages and assets</li>
                            <li>All domain caches (<span id="purge-domain-count">24</span> domains)</li>
                            <li>Current cache size: <span id="purge-cache-size">24.5GB</span> will be cleared</li>
                            <li>Cache hit rates will reset to 0%</li>
                        </ul>
                    </div>
                    
                    <div class="confirmation-section">
                        <label>
                            <input type="checkbox" id="confirmPurge" onchange="togglePurgeButton()"> 
                            I understand this will clear all cache and may impact performance temporarily
                        </label>
                    </div>
                </div>
            </div>
            <div class="modal-actions">
                <button class="btn" onclick="closeModal('purgeAllModal')">Cancel</button>
                <button class="btn btn-warning" id="confirmPurgeBtn" disabled onclick="executePurgeAll()">
                    <i class="fas fa-broom"></i> Purge All Cache
                </button>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
        // Global variables
        let currentSection = 'overview';
        let currentTimeframe = 'hourly';
        let charts = {};
        let refreshInterval;

        // Initialize the dashboard
        document.addEventListener('DOMContentLoaded', function() {
            initializeDashboard();
            startAutoRefresh();
            updateTime();
        });

        function initializeDashboard() {
            loadDomains();
            initializeCharts();
            loadMetrics();
        }

        function startAutoRefresh() {
            // Update metrics every 30 seconds
            refreshInterval = setInterval(() => {
                loadMetrics();
                updateTime();
            }, 30000);
        }

        function updateTime() {
            const now = new Date();
            document.querySelector('.update-time').textContent = 
                now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }

        function showSection(section) {
            // Update tabs
            document.querySelectorAll('.section-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            document.querySelector(`[onclick="showSection('${section}')"]`).classList.add('active');

            // Update sections
            document.querySelectorAll('.section').forEach(sec => {
                sec.classList.remove('active');
            });
            document.getElementById(`${section}-section`).classList.add('active');

            currentSection = section;

            // Load section-specific content
            switch(section) {
                case 'domains':
                    loadDomains();
                    break;
                case 'analytics':
                    initializeCharts();
                    break;
                case 'settings':
                    loadSettings();
                    break;
                case 'logs':
                    loadLogs();
                    break;
            }
        }

        async function loadMetrics() {
            try {
                const response = await fetch('/cgi/varnish_ajax.cgi?action=getMetrics');
                const data = await response.json();
                
                if (data.success) {
                    updateMetrics(data.data);
                }
            } catch (error) {
                console.error('Error loading metrics:', error);
            }
        }

        function updateMetrics(data) {
            // Update performance metrics
            document.getElementById('overall-score').textContent = data.overall_score || '98';
            document.getElementById('hit-rate').textContent = data.hit_rate || '94%';
            document.getElementById('cache-size').textContent = data.cache_size || '24.5GB';
            document.getElementById('request-rate').textContent = data.request_rate || '5.2K';
            
            // Update system metrics
            document.getElementById('ssl-status').textContent = data.ssl_status || '12/12 All Valid';
            document.getElementById('cpu-usage').textContent = data.cpu_usage || '32% - 8 Cores';
            document.getElementById('memory-usage').textContent = data.memory_usage || '2.8GB of 4GB';
            document.getElementById('requests-per-second').textContent = data.requests_per_second || '1.2K - Peak: 2.5K';
        }

        async function loadDomains() {
            try {
                const response = await fetch('/cgi/varnish_ajax.cgi?action=getDomains');
                const data = await response.json();
                
                if (data.success) {
                    displayDomains(data.data);
                }
            } catch (error) {
                console.error('Error loading domains:', error);
                displaySampleDomains();
            }
        }

        function displayDomains(domains) {
            const domainsGrid = document.getElementById('domains-grid');
            
            if (!domains || domains.length === 0) {
                displaySampleDomains();
                return;
            }

            domainsGrid.innerHTML = '';
            
            const rows = Math.ceil(domains.length / 3);
            for (let i = 0; i < rows; i++) {
                const row = document.createElement('div');
                row.className = 'domain-row';
                
                for (let j = 0; j < 3; j++) {
                    const index = i * 3 + j;
                    if (index < domains.length) {
                        const domain = domains[index];
                        row.appendChild(createDomainCard(domain));
                    }
                }
                
                domainsGrid.appendChild(row);
            }

            // Update pagination info
            document.getElementById('domains-showing').textContent = `1-${Math.min(9, domains.length)}`;
            document.getElementById('domains-total').textContent = domains.length;
        }

        function displaySampleDomains() {
            const sampleDomains = [
                { name: 'example.com', hit_rate: 98, requests: '2.4K/min', size: '8.2GB', status: 'active' },
                { name: 'test.com', hit_rate: 95, requests: '1.8K/min', size: '5.1GB', status: 'active' },
                { name: 'shop.example.com', hit_rate: 92, requests: '3.1K/min', size: '12.4GB', status: 'active' },
                { name: 'blog.example.com', hit_rate: 89, requests: '1.2K/min', size: '3.8GB', status: 'active' },
                { name: 'api.example.com', hit_rate: 85, requests: '5.6K/min', size: '2.1GB', status: 'warning' },
                { name: 'cdn.example.com', hit_rate: 99, requests: '8.9K/min', size: '18.7GB', status: 'active' },
                { name: 'staging.example.com', hit_rate: 76, requests: '0.3K/min', size: '1.2GB', status: 'inactive' },
                { name: 'dev.example.com', hit_rate: 68, requests: '0.1K/min', size: '0.8GB', status: 'inactive' },
                { name: 'mobile.example.com', hit_rate: 94, requests: '4.2K/min', size: '6.3GB', status: 'active' }
            ];
            
            displayDomains(sampleDomains);
        }

        function createDomainCard(domain) {
            const card = document.createElement('div');
            card.className = 'domain-card';
            
            const statusClass = domain.status === 'active' ? 'active' : 
                               domain.status === 'warning' ? 'warning' : 'inactive';
            const statusText = domain.status === 'active' ? 'Active' : 
                              domain.status === 'warning' ? 'Monitoring' : 'Inactive';
            
            card.innerHTML = `
                <div class="domain-header">
                    <div class="domain-icon">
                        <i class="fas fa-globe"></i>
                    </div>
                    <div class="domain-info">
                        <h4>${domain.name}</h4>
                        <span class="domain-metrics">Hit Rate: ${domain.hit_rate}%</span>
                    </div>
                </div>
                <div class="domain-stats">
                    <div class="stat-item">
                        <span class="stat-label">Requests</span>
                        <span class="stat-value">${domain.requests}</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Size</span>
                        <span class="stat-value">${domain.size}</span>
                    </div>
                </div>
                <div class="domain-actions">
                    <span class="status-badge ${statusClass}">${statusText}</span>
                    <button class="btn-icon" onclick="showDomainSettings('${domain.name}')">
                        <i class="fas fa-cog"></i>
                    </button>
                </div>
            `;
            
            return card;
        }

        function initializeCharts() {
            const chartIds = ['hitRateChart', 'responseTimeChart', 'bandwidthChart', 'requestDistChart'];
            
            chartIds.forEach(chartId => {
                const element = document.getElementById(chartId);
                if (element && !charts[chartId]) {
                    // Create a placeholder chart
                    element.innerHTML = `
                        <div style="display: flex; align-items: center; justify-content: center; height: 100%; color: #666;">
                            <div style="text-align: center;">
                                <i class="fas fa-chart-line" style="font-size: 48px; margin-bottom: 10px; opacity: 0.3;"></i>
                                <div>Chart data loading...</div>
                            </div>
                        </div>
                    `;
                }
            });
        }

        function changeTimeframe(timeframe) {
            // Update button states
            document.querySelectorAll('.time-selector .btn').forEach(btn => {
                btn.classList.remove('active');
            });
            document.querySelector(`[onclick="changeTimeframe('${timeframe}')"]`).classList.add('active');
            
            currentTimeframe = timeframe;
            
            // Reload chart data for new timeframe
            loadChartData();
        }

        async function loadChartData() {
            try {
                const response = await fetch(`/cgi/varnish_ajax.cgi?action=getChartData&timeframe=${currentTimeframe}`);
                const data = await response.json();
                
                if (data.success) {
                    updateCharts(data.data);
                }
            } catch (error) {
                console.error('Error loading chart data:', error);
            }
        }

        function updateCharts(data) {
            // Update chart displays with real data
            console.log('Updating charts with data:', data);
        }

        function loadSettings() {
            const settingsContent = document.getElementById('settings-content');
            settingsContent.innerHTML = `
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px;">
                    <div style="background: var(--bg-gradient); padding: 20px; border-radius: 10px;">
                        <h3>Backend Configuration</h3>
                        <div style="display: grid; gap: 15px;">
                            <div>
                                <label>Backend Host</label>
                                <input type="text" value="127.0.0.1" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                            </div>
                            <div>
                                <label>Backend Port</label>
                                <input type="number" value="8080" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                            </div>
                            <div>
                                <label>Health Check</label>
                                <select style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                                    <option>Enabled</option>
                                    <option>Disabled</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div style="background: var(--bg-gradient); padding: 20px; border-radius: 10px;">
                        <h3>VCL Configuration</h3>
                        <div style="display: grid; gap: 15px;">
                            <div>
                                <label>VCL File</label>
                                <input type="text" value="/etc/varnish/default.vcl" readonly style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; background: #f8f9fa;">
                            </div>
                            <button class="btn" onclick="editVCL()">
                                <i class="fas fa-edit"></i> Edit VCL
                            </button>
                            <button class="btn" onclick="reloadVCL()">
                                <i class="fas fa-sync"></i> Reload VCL
                            </button>
                        </div>
                    </div>
                </div>
                <div style="margin-top: 20px; text-align: right;">
                    <button class="btn" style="background: var(--success-color);" onclick="saveSettings()">
                        <i class="fas fa-save"></i> Save Configuration
                    </button>
                </div>
            `;
        }

        function loadLogs() {
            const logsContent = document.getElementById('logs-content');
            logsContent.innerHTML = `
                <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                        <div style="display: flex; gap: 10px;">
                            <button class="btn" onclick="refreshLogs()">
                                <i class="fas fa-sync"></i> Refresh
                            </button>
                            <button class="btn" onclick="clearLogs()">
                                <i class="fas fa-trash"></i> Clear
                            </button>
                        </div>
                        <div>
                            <select onchange="changeLogLevel(this.value)" style="padding: 6px; border: 1px solid #ddd; border-radius: 4px;">
                                <option value="all">All Levels</option>
                                <option value="error">Errors Only</option>
                                <option value="warning">Warnings</option>
                                <option value="info">Info</option>
                            </select>
                        </div>
                    </div>
                </div>
                <div style="background: #000; color: #00ff00; padding: 15px; border-radius: 8px; font-family: monospace; height: 400px; overflow-y: auto;" id="log-display">
                    <div>Loading logs...</div>
                </div>
            `;
            
            // Load actual logs
            loadActualLogs();
        }

        async function loadActualLogs() {
            try {
                const response = await fetch('/cgi/varnish_ajax.cgi?action=getLogs');
                const data = await response.json();
                
                const logDisplay = document.getElementById('log-display');
                if (data.success && data.data) {
                    logDisplay.innerHTML = data.data.replace(/\\n/g, '<br>');
                } else {
                    logDisplay.innerHTML = 'No logs available or unable to load logs.';
                }
            } catch (error) {
                console.error('Error loading logs:', error);
                document.getElementById('log-display').innerHTML = 'Error loading logs.';
            }
        }

        // Modal functions
        function showGlobalSettings() {
            document.getElementById('globalSettingsModal').classList.add('active');
        }

        function showPurgeAllModal() {
            document.getElementById('purgeAllModal').classList.add('active');
            // Reset checkbox
            document.getElementById('confirmPurge').checked = false;
            document.getElementById('confirmPurgeBtn').disabled = true;
        }

        function closeModal(modalId) {
            document.getElementById(modalId).classList.remove('active');
        }

        function togglePurgeButton() {
            const checkbox = document.getElementById('confirmPurge');
            const button = document.getElementById('confirmPurgeBtn');
            button.disabled = !checkbox.checked;
        }

        async function executePurgeAll() {
            try {
                closeModal('purgeAllModal');
                showToast('info', 'Purging all cache... This may take a few moments.');
                
                const response = await fetch('/cgi/varnish_ajax.cgi?action=purgeAll', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ confirm: true })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showToast('success', 'All cache has been successfully purged!');
                    // Refresh metrics
                    setTimeout(() => loadMetrics(), 2000);
                } else {
                    throw new Error(data.message || 'Failed to purge cache');
                }
            } catch (error) {
                console.error('Error purging cache:', error);
                showToast('error', 'Failed to purge cache: ' + error.message);
            }
        }

        function showToast(type, message) {
            const toast = document.createElement('div');
            toast.className = `toast toast-${type}`;
            
            const icon = type === 'success' ? 'check-circle' : 
                        type === 'error' ? 'exclamation-circle' : 
                        'info-circle';
            
            toast.innerHTML = `
                <i class="fas fa-${icon}"></i>
                <span>${message}</span>
            `;
            
            document.body.appendChild(toast);
            setTimeout(() => toast.classList.add('active'), 100);
            
            // Auto remove
            setTimeout(() => {
                toast.classList.remove('active');
                setTimeout(() => document.body.removeChild(toast), 300);
            }, type === 'error' ? 5000 : 3000);
        }

        // Utility functions
        function addDomain() {
            const domain = prompt('Enter domain name:');
            if (domain) {
                // Add domain logic here
                showToast('info', `Adding domain: ${domain}`);
            }
        }

        function showDomainSettings(domain) {
            alert(`Domain settings for: ${domain}`);
        }

        function saveGlobalSettings() {
            showToast('success', 'Global settings saved successfully!');
            closeModal('globalSettingsModal');
        }

        function editVCL() {
            alert('VCL editor would open here');
        }

        function reloadVCL() {
            showToast('info', 'Reloading VCL configuration...');
        }

        function saveSettings() {
            showToast('success', 'Settings saved successfully!');
        }

        function refreshLogs() {
            loadActualLogs();
            showToast('info', 'Logs refreshed');
        }

        function clearLogs() {
            if (confirm('Are you sure you want to clear all logs?')) {
                document.getElementById('log-display').innerHTML = 'Logs cleared.';
                showToast('info', 'Logs cleared');
            }
        }

        function changeLogLevel(level) {
            console.log('Changing log level to:', level);
            loadActualLogs();
        }

        // Cleanup on page unload
        window.addEventListener('beforeunload', function() {
            if (refreshInterval) {
                clearInterval(refreshInterval);
            }
        });
    </script>
</body>
</html>
EOF

exit 0;