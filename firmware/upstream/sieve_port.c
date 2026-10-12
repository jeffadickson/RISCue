#include <stdint.h>
#include <stdbool.h>
void sieve(void);
volatile uint32_t observed_checksum;
volatile uint32_t print_fail;
void print_str(const char *s) { if(s[0]==' ' && s[1]=='E') print_fail=1; }
void print_dec(unsigned int value) { (void)value; }
void print_hex(unsigned int value,int digits) { observed_checksum=value;(void)digits; }
int main(void) { sieve(); return observed_checksum==0x1772a48f && !print_fail ? 0:1; }
