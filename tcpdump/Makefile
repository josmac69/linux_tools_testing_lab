.PHONY: docker-build run clean

# Build the sniffer container
docker-build:
	docker compose build

# Start the lab network (web-server, client generator, and tcpdump sniffer)
# Ctrl+C will stop the containers
run: docker-build
	@echo "=== Starting Tcpdump Lab Stack ==="
	@echo "Watch the terminal output below for captured HTTP requests..."
	docker compose up

# Tear down the lab network containers and network interfaces
clean:
	docker compose down --remove-orphans
