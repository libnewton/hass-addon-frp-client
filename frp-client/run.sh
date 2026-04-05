#!/usr/bin/env bashio

WAIT_PIDS=()
CONFIG_PATH='/share/frpc.toml'

# Write configuration files from UI textareas to /share
bashio::log.info "Writing configuration files from UI to /share..."

# Read and write the main TOML config
# Using bashio::config to pull the string content directly into the files
bashio::config 'frpc_toml_content' > "$CONFIG_PATH"
bashio::config 'frp_token_content' > /share/frp_token
bashio::config 'frp_ca_crt_content' > /share/frp_ca.crt
bashio::config 'frp_client_crt_content' > /share/frp_client.crt
bashio::config 'frp_client_key_content' > /share/frp_client.key

# Set restrictive permissions for the private key
chmod 600 /share/frp_client.key 2>/dev/null || true

function stop_frpc() {
    bashio::log.info "Shutting down frpc client..."
    kill -15 "${WAIT_PIDS[@]}"
}

bashio::log.info "Starting frp client with the following config:"
cat "$CONFIG_PATH"

cd /usr/src
# Start frpc using the generated config file
./frpc -c "$CONFIG_PATH" & WAIT_PIDS+=($!)

# Ensure log file exists so tail doesn't fail
touch /share/frpc.log
tail -f /share/frpc.log &

trap "stop_frpc" SIGTERM SIGHUP
wait "${WAIT_PIDS[@]}"
