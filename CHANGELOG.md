# Changelog

All notable changes to the Nginx Proxy Manager with SSH Tunnel project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet

### Changed
- Nothing yet

### Deprecated
- Nothing yet

### Removed
- Nothing yet

### Fixed
- Nothing yet

### Security
- Nothing yet

## [1.0.0] - 2025-06-02

### Added
- Initial release of Nginx Proxy Manager with SSH Tunnel
- Docker container based on `jc21/nginx-proxy-manager:2`
- Automatic SSH tunnel establishment using autossh
- SSH key generation and management
- Password-based and key-based SSH authentication support
- Configurable tunnel monitoring and health checks
- Automatic tunnel reconnection on failures
- Support for custom SSH ports, users, and remote ports
- Comprehensive logging and status monitoring
- s6-overlay service integration for robust process management
- Network connectivity validation before tunnel establishment
- Configurable check intervals and failure thresholds
- Docker Compose configuration with environment variables
- Volume mapping for data persistence
- SSH key persistence across container restarts
