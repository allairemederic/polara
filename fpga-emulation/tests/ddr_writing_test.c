#include <stdio.h>
#include <stdint.h>

#define RESULT_ADDR 0x88000000UL
#define EVICT_ADDR  0x89000000UL

int main() {

  volatile uint64_t *results = (volatile uint64_t *)RESULT_ADDR;
  volatile uint64_t *evict = (volatile uint64_t *)EVICT_ADDR;

  results[0] = 0xAAAABBBB;
  results[1] = 0x12345678;

  // Temporary cache eviction workaround
  for (int i = 0; i < (1024 * 1024 / 8); i++)
  {
    evict[i] = i;
  }

  return 0;
}