#define NULL 0

int getchar(void);
int putchar(int c);
int puts(const char* p);
// We need to declare malloc as int* to reduce bitcasts */
int* calloc(int n, int s);
void free(void* p);
void exit(int s);

#ifdef __GNUC__
__attribute__((noinline))
#endif
static void print_int(int v) {
  int n = 0;
  int buf[16];
  do {
    buf[n] = v % 10;
    v /= 10;
    n++;
  } while (v);

  while (n--) {
    putchar(buf[n] + '0');
  }
}

static void print_str(int* p) {
  while (*p) {
    putchar(*p);
    p++;
  }
}

#ifndef __GNUC__

int puts(const char* p) {
  print_str(p);
  putchar('\n');
}

extern int* _edata;

int* calloc(int n, int s) {
  int* r = _edata;
  // We assume s is the size of int.
  _edata += n;
  return r;
}

void free(void* p) {
}

#endif

static int __builtin_mul(int a, int b) {
  int r = 0;
  while (a--) {
    r += b;
  }
  return r;
}

static unsigned int __builtin_div(unsigned int a, unsigned int b) {
  unsigned int r = 0;
  unsigned int n;
  while (1) {
    n = a - b;
    if (n > a)
      break;
    ++r;
    a = n;
  }
  return r;
}

static unsigned int __builtin_mod(unsigned int a, unsigned int b) {
  return a - a / b * b;
}
