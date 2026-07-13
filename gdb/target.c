#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void secret_function() {
    printf("\n[SUCCESS] Wow! You redirected execution to the secret function!\n");
}

void buggy_function(char *str) {
    char buffer[16];
    printf("buggy_function: Copying string of length %lu into 16-byte buffer...\n", strlen(str));
    // Vulnerable to stack overflow: no bounds checking
    strcpy(buffer, str);
    printf("buggy_function: Buffer content: %s\n", buffer);
}

int main(int argc, char **argv) {
    printf("=== GDB Lab Target Program ===\n");
    if (argc < 2) {
        printf("No arguments provided. Triggering a NULL pointer dereference...\n");
        char *ptr = NULL;
        // This will trigger a Segmentation Fault (SIGSEGV)
        printf("Dereferencing NULL: %c\n", *ptr);
        return 1;
    }
    
    buggy_function(argv[1]);
    printf("Main function completed successfully.\n");
    return 0;
}
