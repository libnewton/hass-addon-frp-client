#!/usr/bin/env bashio

WAIT_PIDS=()
CONFIG_PATH='/share/frpc.toml'

# Function to write config if data exists
write_config_file() {
    local key=$1
    local path=$2
    if bashio::config.has_value "$key"; then
        bashio::log.info "Updating file: $path (Key: $key)"
        bashio::config "$key" > "$path"
    else
        bashio::log.warn "Configuration key '$key' is empty. Skipping $path."
    fi
}

bashio::log.info "Processing configuration files..."

# Write configuration files from UI
write_config_file 'frpc_toml_content' "$CONFIG_PATH"
write_config_file 'frp_token_content' '/share/frp_token'
write_config_file 'frp_ca_crt_content' '/share/frp_ca.crt'
write_config_file 'frp_client_crt_content' '/share/frp_client.crt'
write_config_file 'frp_client_key_content' '/share/frp_client.key'

# Set restrictive permissions for the private key
if [ -f /share/frp_client.key ]; then
    chmod 600 /share/frp_client.key
fi

function stop_frpc() {
    bashio::log.info "Shutting down frpc client..."
    kill -15 "${WAIT_PIDS[@]}"
}

# Check if config exists before starting
if [ ! -s "$CONFIG_PATH" ]; then
    bashio::log.error "Config file $CONFIG_PATH is empty or missing! Check your Addon Options."
    exit 1
fi

bashio::log.info "Starting frp client..."
cd /usr/src
./frpc -c "$CONFIG_PATH" & WAIT_PIDS+=($!)

# Ensure log file exists
touch /share/frpc.log
tail -f /share/frpc.log &

trap "stop_frpc" SIGTERM SIGHUP
wait "${WAIT_PIDS[@]}"
