.PHONY: build clean

# Build all GDB sub-labs
build:
	make -C 01_basic_crash docker-build
	make -C 02_postgres_debug docker-build
	make -C 03_mysql_debug docker-build

# Clean up all GDB sub-labs
clean:
	make -C 01_basic_crash clean
	make -C 02_postgres_debug clean
	make -C 03_mysql_debug clean
