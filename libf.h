#define NULL 0

typedef unsigned long size_t;
typedef unsigned long ptrdiff_t;
typedef long off_t;
typedef unsigned char uint8_t;
typedef int bool;
#define true 1
#define false 0
#define offsetof(type, field) ((size_t) &((type *)0)->field)
#define EOF -1

typedef char* va_list;
#define va_start(ap, last) ap = &last
#define va_arg(ap, type) *(type*)++ap
#define va_end(ap)

int getchar(void);
int putchar(int c);
int puts(const char* p);
// We need to declare malloc as int* to reduce bitcasts */
int* calloc(int n, int s);
void free(void* p);
void exit(int s);

void* memset(void* d, int c, size_t n) {
  size_t i;
  for (i = 0; i < n; i++) {
    ((char*)d)[i] = c;
  }
  return d;
}

void* memcpy(void* d, const void* s, size_t n) {
  size_t i;
  for (i = 0; i < n; i++) {
    ((char*)d)[i] = ((char*)s)[i];
  }
  return d;
}

size_t strlen(const char* s) {
  size_t r;
  for (r = 0; s[r]; r++) {}
  return r;
}

char* strcat(char* d, const char* s) {
  char* r = d;
  for (; *d; d++) {}
  for (; *s; s++, d++)
    *d = *s;
  return r;
}

char* strcpy(char* d, const char* s) {
  char* r = d;
  for (; *s; s++, d++)
    *d = *s;
  return r;
}

int strcmp(const char* a, const char* b) {
  for (;*a || *b; a++, b++) {
    if (*a < *b)
      return -1;
    if (*a > *b)
      return 1;
  }
  return 0;
}

char* strchr(char* s, int c) {
  for (; *s; s++) {
    if (*s == c)
      return s;
  }
  return NULL;
}

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

static void print_str(const char* p) {
  for (; *p; p++)
    putchar(*p);
}

static char* stringify_int(long v, char* p) {
  int is_negative = 0;
  *p = '\0';
  if (v < 0) {
    v = -v;
    is_negative = 1;
  }
  do {
    --p;
    *p = v % 10 + '0';
    v /= 10;
  } while (v);
  if (is_negative)
    *--p = '-';
  return p;
}

static void print_int(long v) {
  char buf[32];
  print_str(stringify_int(v, buf + sizeof(buf) - 1));
}

static char* stringify_hex(long v, char* p) {
  int is_negative = 0;
  int c;
  *p = '\0';
  if (v < 0) {
    v = -v;
    is_negative = 1;
  }
  do {
    --p;
    c = v % 16;
    *p = c < 10 ? c + '0' : c - 10 + 'A';
    v /= 16;
  } while (v);
  if (is_negative)
    *--p = '-';
  return p;
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

int vsprintf(char* buf, const char* fmt, va_list ap) {
  static const char kOverflowMsg[] = " *** OVERFLOW! ***\n";
  const size_t kMaxFormattedStringSize = sizeof(buf) - sizeof(kOverflowMsg);
  char* outp = buf;
  const char* inp;
  int is_overflow = 0;

  for (inp = fmt; *inp && (outp - buf) < kMaxFormattedStringSize; inp++) {
    if (*inp != '%') {
      *outp++ = *inp;
      if (outp - buf >= kMaxFormattedStringSize) {
        is_overflow = 1;
        break;
      }
      continue;
    }

    char cur_buf[32];
    char* cur_p;
    switch (*++inp) {
      case 'd':
        cur_p = stringify_int(va_arg(ap, long), cur_buf + sizeof(cur_buf) - 1);
        break;
      case 'x':
        cur_p = stringify_hex(va_arg(ap, long), cur_buf + sizeof(cur_buf) - 1);
        break;
      case 's':
        cur_p = va_arg(ap, char*);
        break;
      default:
        print_str("unknown format!\n");
        exit(1);
    }

    size_t len = strlen(cur_p);
    if (outp + len - buf >= kMaxFormattedStringSize) {
      is_overflow = 1;
      break;
    }
    strcat(buf, cur_p);
    outp += len;
  }

  if (strlen(buf) > kMaxFormattedStringSize) {
    print_str(buf);
    if (is_overflow)
      print_str(kOverflowMsg);
    // This should not happen.
    exit(1);
  }
  if (is_overflow)
    strcat(buf, kOverflowMsg);
}

int snprintf(char* buf, size_t size, const char* fmt, ...) {
  // TODO: Handle size?
  va_list ap;
  va_start(ap, fmt);
  vsprintf(fmt, ap);
  va_end(ap);
}

int vprintf(const char* fmt, va_list ap) {
  char buf[300] = {0};
  vsprintf(buf, fmt, ap);
  print_str(buf);
  return 0;
}

int printf(const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vprintf(fmt, ap);
  va_end(ap);
}

void* stdout;
void* stderr;

int fprintf(void* fp, const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vprintf(fmt, ap);
  va_end(ap);
}

int vfprintf(void* fp, const char* fmt, va_list ap) {
  return vprintf(fmt, ap);
}

#define PROT_READ 1
#define PROT_WRITE 2
#define PROT_EXEC 4
#define MAP_PRIVATE 2
#define MAP_ANON 0x20
void* mmap(void* addr, size_t length, int prot, int flags,
           int fd, off_t offset) {
  return calloc(length, 2);
}

void munmap(void* addr, size_t length) {
}

#define assert(x)                               \
  if (!(x)) {                                   \
    printf("assertion failed: %s\n", #x);       \
    exit(1);                                    \
  }

int isdigit(int c) {
  return '0' <= c && c <= '9';
}

int isalpha(int c) {
  return ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z');
}

int isalnum(int c) {
  return isalpha(c) || isdigit(c);
}

char* getenv(const char* name) {
  return NULL;
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
