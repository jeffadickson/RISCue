/* Source-level GDB fixture: no runtime library required. */
volatile unsigned answer;
__attribute__((noinline)) void debug_done(void) { __asm__ volatile("nop"); }
int main(void) {
    answer = 21;
    answer = answer * 2;
    debug_done();
    return (int)answer;
}
