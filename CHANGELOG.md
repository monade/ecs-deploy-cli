# Changelog
All notable changes to this project made by Monade Team are documented in this file. For info refer to team@monade.io

## [0.5.0] - 2021-07-16
### Added
- Command `setup` now create the keypair if it's missing
- `deploy-scheduled-tasks` now creates scheduled tasks if not already there

### Fixed
- Command `setup` now raises error when the IAM role `ecsInstanceRole` doesn't exist in your account
- Command `setup` now considers inactive clusters and services as deleted

## [0.4.0] - 2021-05-24
### Changed
- The command `ssh` now handles multiple container instances. You can now filter by task or service. If there are multiple options, it will be prompted.

## [0.3.0] - 2021-05-19
### Added
- new command `setup` that creates the cluster and all the services
- If you select "cloudwatch" as log target for your container, the log groups get automatically created
- Allow setting up load balancers for services

## [0.2.2] - 2021-04-01
### Fixed
- Command `diff` was showing a bunch of junk data
- Added `frozen_string_literal: true` when missing

### Changed
- The color for "modified value" is now yellow

## [0.2.1] - 2021-03-25
### Fixed
- Broken deploy command passing wrong task name

## [0.2.0] - 2021-03-25
### Added
- Command run-task
- Command diff
- Made automatic options explicit
- Deploy scheduled tasks
- Refactoring runners

## [0.1.0] - 2021-03-21
First functional version

### Added
- README
- CHANGELOG
- LICENSE
- tests
