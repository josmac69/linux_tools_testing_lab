.PHONY: build docker-build run run-summary clean

# Compile the target locally
build: target.c
	gcc -o target target.c

# Build the lab Docker image
docker-build:
	docker build -t lab-strace .

# Run the container and trace all system calls
# Requires SYS_PTRACE capability to monitor process syscalls
run: docker-build
	docker run --cap-add=SYS_PTRACE --rm lab-strace strace ./target

# Run the container and print a summary table of system calls
run-summary: docker-build
	docker run --cap-add=SYS_PTRACE --rm lab-strace strace -c ./target

clean:
	rm -f target
