#include <stdio.h>
#include <stdlib.h>

#define SIZE 2000
#define ITERATIONS 100

// Declare matrix on the heap/data segment to avoid stack overflow
int matrix[SIZE][SIZE];

int main() {
    printf("Fast matrix test: row-major traversal (%d iterations)...\n", ITERATIONS);
    
    for (int i = 0; i < ITERATIONS; i++) {
        for (int row = 0; row < SIZE; row++) {
            for (int col = 0; col < SIZE; col++) {
                // Accessing matrix[row][col] causes sequential (contiguous) memory access
                matrix[row][col] += (row + col);
            }
        }
    }
    
    printf("Done. matrix[0][0] = %d\n", matrix[0][0]);
    return 0;
}
