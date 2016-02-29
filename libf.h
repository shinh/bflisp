#define NULL 0

int getchar(void);
int putchar(int c);
int puts(const char* p);
// We need to declare malloc as int* to reduce bitcasts */
int* calloc(int n, int s);
void free(void* p);
void exit(int s);

typedef struct {
  int quot, rem;
} div_t;

// Our 8cc doesn't support returning a structure value.
// TODO: update 8cc.
void my_div(unsigned int a, unsigned int b, div_t* o) {
  unsigned int q = 0;
  unsigned int n;
  while (1) {
    n = a - b;
    if (n > a)
      break;
    ++q;
    a = n;
  }
  o->quot = q;
  o->rem = a;
}

static void print_int(int v) {
  int n = 0;
  int buf[16];
  do {
    div_t d;
    my_div(v, 10, &d);
    buf[n] = d.rem;
    v = d.quot;
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
  div_t r;
  my_div(a, b, &r);
  return r.quot;
}

static unsigned int __builtin_mod(unsigned int a, unsigned int b) {
  div_t r;
  my_div(a, b, &r);
  return r.rem;
}
