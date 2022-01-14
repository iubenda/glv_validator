# GVL Validator

Validate all `deviceStorageDisclosureUrl` jsons in the GVL and report errors.

## Usage

##### Development

```bash
# Install gems and clone config files (config.yml, .env)
bin/setup -d

# Build web page with validation report
rake web:build

# Serve page locally (on locahost:8080)
rake web:serve
```

##### Production

```bash
# Install gems and clone config files (config.yml, schedule.rb)
bin/setup -p

# Customize schedule.rb then update crontab
whenever --update-crontab
```
