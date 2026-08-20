#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#define UART_BASE 0xFFF0C2C000
#define UART_INTERRUPT_ENABLE UART_BASE + 1
#define UART_LINE_CONTROL UART_BASE + 3
#define UART_MODEM_CONTROL UART_BASE + 4
#define UART_LINE_STATUS UART_BASE + 5
#define UART_MODEM_STATUS UART_BASE + 6
#define UART_DLAB_LSB UART_BASE + 0
#define UART_DLAB_MSB UART_BASE + 1

void write_reg_u8(uintptr_t addr, uint8_t value){
    volatile uint8_t *loc_addr = (volatile uint8_t *)addr;
    *loc_addr = value;
}

void init_uart(uint32_t freq, uint32_t baud) {
  uint32_t divisor = freq / (baud << 4);
  write_reg_u8(UART_INTERRUPT_ENABLE, 0x00); // Disable all interrupts
  write_reg_u8(UART_LINE_CONTROL, 0x80);     // Enable DLAB (set baud rate divisor)
  write_reg_u8(UART_DLAB_LSB, divisor);         // divisor (lo byte)
  write_reg_u8(UART_DLAB_MSB, (divisor >> 8) & 0xFF);  // divisor (hi byte)
  write_reg_u8(UART_LINE_CONTROL, 0x03);     // 8 bits, no parity, one stop bit
  write_reg_u8(UART_MODEM_CONTROL, 0x20);    // Autoflow mode
}

int main(int argc, char ** argv) {

  init_uart(50000000, 115200);

   printf("\n");
   printf("=====================================\n");
   printf(" Hello World from POLARA \n");
   printf("=====================================\n");
   printf("\n");

  for (int k = 0; k < 32; k++) {
    // assemble number and print
    printf("Hello world, I am MEDE %d! Counting (%d of 32)...\n", argv[0][0], k);
  }

  printf("Done!\n");

  return 0;
}