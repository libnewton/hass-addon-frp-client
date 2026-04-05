#!/usr/bin/env bashio

WAIT_PIDS=()
CONFIG_PATH='/share/frpc.toml'

bashio::log.info "Processing configuration files..."

# Function to safely write config keys to files
save_config() {
    local key=$1
    local target=$2
    
    # Check if the key exists and has a value
    if bashio::config.has_value "$key"; then
        bashio::log.info "Writing $key to $target"
        # We use 'printf' to handle potential special characters in the string
        printf "%s" "$(bashio::config "$key")" > "$target"
    else
        bashio::log.warn "Config key '$key' is empty. Skipping $target."
    fi
}

# Ensure we can write to /share
if ! touch /share/.test_bit 2>/dev/null; then
    bashio::log.error "Cannot write to /share. Is the 'share' folder mapped correctly?"
    exit 1
fi
rm /share/.test_bit

# Save all files from UI inputs
save_config 'frpc_toml_content' "$CONFIG_PATH"
save_config 'frp_token_content' '/share/frp_token'
save_config 'frp_ca_crt_content' '/share/frp_ca.crt'
save_config 'frp_client_crt_content' '/share/frp_client.crt'
save_config 'frp_client_key_content' '/share/frp_client.key'

# Set restrictive permissions for the private key
if [ -f /share/frp_client.key ]; then
    chmod 600 /share/frp_client.key
fi

# Final check: Does the main config actually exist now?
if [ ! -s "$CONFIG_PATH" ]; then
    bashio::log.error "Critical Error: $CONFIG_PATH is empty! Please paste your config in the Addon Options UI."
    exit 1
fi

function stop_frpc() {
    bashio::log.info "Shutting down frpc client..."
    kill -15 "${WAIT_PIDS[@]}"
}

bashio::log.info "Starting frpc..."
cd /usr/src
./frpc -c "$CONFIG_PATH" & WAIT_PIDS+=($!)

# Ensure log file exists so tail doesn't fail
touch /share/frpc.log
tail -f /share/frpc.log &

trap "stop_frpc" SIGTERM SIGHUP
wait "${WAIT_PIDS[@]}"
