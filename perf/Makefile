.PHONY: build docker-build clean

# Build all perf sub-labs
build:
	$(MAKE) -C 01_matrix_cache docker-build
	$(MAKE) -C 02_postgres_perf docker-build
	$(MAKE) -C 03_mysql_perf docker-build

# Top-level workspace Makefile calls docker-build
docker-build: build

# Clean all perf sub-labs
clean:
	$(MAKE) -C 01_matrix_cache clean
	$(MAKE) -C 02_postgres_perf clean
	$(MAKE) -C 03_mysql_perf clean
