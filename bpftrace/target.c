#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <time.h>

int main() {
    pid_t pid = getpid();
    printf("=== BPFtrace Lab Activity Generator ===\n");
    printf("Process PID: %d. Running in a loop to generate trace events...\n", pid);
    printf("Press Ctrl+C to terminate.\n\n");
    
    // Seed random number generator
    srand(time(NULL));
    
    const char *temp_file = "/tmp/bpftrace_activity.txt";
    
    while (1) {
        // Open file (triggers sys_enter_openat tracepoint)
        int fd = open(temp_file, O_CREAT | O_WRONLY | O_TRUNC, 0644);
        if (fd >= 0) {
            // Generate a random write size between 1 and 100 bytes
            int size = (rand() % 100) + 1;
            char *buf = malloc(size);
            if (buf) {
                // Populate buffer
                for (int i = 0; i < size; i++) buf[i] = 'A';
                
                // Write buffer (triggers sys_enter_write tracepoint)
                write(fd, buf, size);
                free(buf);
            }
            // Close file
            close(fd);
        }
        
        // Sleep for 500 milliseconds (triggers nanosleep)
        usleep(500000);
    }
    
    return 0;
}
