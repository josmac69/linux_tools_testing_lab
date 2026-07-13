#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

int main() {
    printf("=== Strace Lab Target Program ===\n");
    
    // 1. open (O_CREAT | O_WRONLY | O_TRUNC) -> triggers openat()
    const char *filename = "strace_demo.txt";
    printf("Creating and writing to file: %s...\n", filename);
    int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("Failed to open file for writing");
        return 1;
    }
    
    // 2. write -> triggers write()
    const char *msg = "Hello from the strace lab!\n";
    write(fd, msg, strlen(msg));
    
    // 3. close -> triggers close()
    close(fd);
    
    // 4. sleep -> triggers nanosleep()
    printf("Sleeping for 100 milliseconds...\n");
    usleep(100000); 
    
    // 5. open (O_RDONLY) -> triggers openat()
    printf("Reading from file: %s...\n", filename);
    fd = open(filename, O_RDONLY);
    if (fd < 0) {
        perror("Failed to open file for reading");
        return 1;
    }
    
    // 6. read -> triggers read()
    char buffer[128];
    read(fd, buffer, sizeof(buffer));
    
    // 7. close -> triggers close()
    close(fd);
    
    // 8. unlink -> triggers unlink() / unlinkat()
    printf("Deleting file: %s...\n", filename);
    unlink(filename);
    
    printf("Target execution finished.\n");
    return 0;
}
