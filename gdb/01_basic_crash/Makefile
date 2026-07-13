.PHONY: build docker-build run clean

# Compile target locally (with debug symbols and disabled stack protection)
build: target.c
	gcc -g -fno-stack-protector -z execstack -o target target.c

# Build the lab Docker image
docker-build:
	docker build -t lab-gdb .

# Run the interactive GDB debugger session inside the container
# Requires SYS_PTRACE capability and unconfined seccomp profile to debug processes
run: docker-build
	docker run -it --rm \
		--cap-add=SYS_PTRACE \
		--security-opt seccomp=unconfined \
		lab-gdb

# Local clean
clean:
	rm -f target
