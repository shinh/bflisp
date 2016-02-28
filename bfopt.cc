#include <stdio.h>
#include <stdlib.h>

#include <algorithm>
#include <iterator>
#include <map>
#include <string>
#include <vector>

typedef unsigned char byte;

using namespace std;

struct Loop;

enum OpType {
  OP_MEM,
  OP_PTR,
  OP_LOOP,
};

struct Op {
  char op;
  int arg;
  Loop* loop;

  Op()
      : op(0), arg(0) {
  }
};

struct Loop {
  vector<Op*> code;
  map<int, int> addsub;
  int ptr;
  bool has_io;

  Loop() {
    reset(NULL);
  }

  void reset(vector<Op*>* out) {
    if (out)
      copy(code.begin(), code.end(), back_inserter(*out));

    code.clear();
    addsub.clear();
    ptr = 0;
    has_io = false;
  }
};

int merge_ops(char add, char sub, const char** code) {
  int r = 0;
  const char* p;
  for (p = *code; *p; p++) {
    if (*p == add)
      r++;
    else if (*p == sub)
      r--;
    else
      break;
  }
  *code = p - 1;
  return r;
}

void parse(const char* code, vector<Op*>* ops) {
  Loop* cur_loop = new Loop();
  vector<int> loop_stack;
  for (const char* p = code; *p; p++) {
    char c = *p;
    Op* op = new Op();
    switch (c) {
      case '+':
      case '-': {
        op->arg = merge_ops('+', '-', &p);
        if (op->arg) {
          op->op = OP_MEM;
          cur_loop->addsub[cur_loop->ptr] += op->arg;
        } else {
          delete op;
          op = NULL;
        }
        break;
      }

      case '>':
      case '<': {
        op->arg = merge_ops('>', '<', &p);
        if (op->arg) {
          op->op = OP_PTR;
          cur_loop->ptr += op->arg;
        } else {
          delete op;
          op = NULL;
        }
        break;
      }

      case '.':
      case ',': {
        op->op = c;
        cur_loop->has_io = true;
        break;
      }

      case '[': {
        cur_loop->reset(ops);
        op->op = c;
        loop_stack.push_back(ops->size());
        break;
      }

      case ']':
        if (loop_stack.empty()) {
          fprintf(stderr, "unmatched close paren\n");
          exit(1);
        }

        if (!cur_loop->has_io && cur_loop->ptr == 0 &&
            cur_loop->addsub[0] == -1) {
          op->op = OP_LOOP;
          op->loop = cur_loop;
          cur_loop = new Loop();
          cur_loop->has_io = true;
        } else {
          cur_loop->reset(ops);
          op->op = c;
          op->arg = loop_stack.back();
          (*ops)[op->arg]->arg = ops->size();
        }
        loop_stack.pop_back();
        break;
    }

    if (op)
      cur_loop->code.push_back(op);
  }

  cur_loop->reset(ops);

  if (!loop_stack.empty()) {
    fprintf(stderr, "unmatched open paren\n");
    exit(1);
  }
}

void check_bound(int mp) {
  if (mp < 0) {
    fprintf(stderr, "memory pointer out of bound\n");
    exit(1);
  }
}

void alloc_mem(size_t mp, vector<byte>* mem) {
  if (mp >= mem->size()) {
    mem->resize(mp * 2);
  }
}

void run(const vector<Op*>& ops) {
  int mp = 0;
  vector<byte> mem(1);
  for (size_t pc = 0; pc < ops.size(); pc++) {
    const Op* op = ops[pc];
    switch (op->op) {
      case '+':
        mem[mp]++;
        break;

      case '-':
        mem[mp]--;
        break;

      case OP_MEM:
        mem[mp] += op->arg;
        break;

      case '>':
        mp++;
        alloc_mem(mp, &mem);
        break;

      case '<':
        mp--;
        check_bound(mp);
        break;

      case OP_PTR:
        mp += op->arg;
        check_bound(mp);
        alloc_mem(mp, &mem);
        break;

      case '.':
        putchar(mem[mp]);
        break;

      case ',':
        mem[mp] = getchar();
        break;

      case '[':
        if (mem[mp] == 0)
          pc = op->arg;
        break;

      case ']':
        pc = op->arg - 1;
        break;

      case OP_LOOP: {
        int v = mem[mp];
        mem[mp] = 0;
        for (map<int, int>::const_iterator iter = op->loop->addsub.begin();
             iter != op->loop->addsub.end();
             ++iter) {
          int p = iter->first;
          int d = iter->second;
          if (p != 0) {
            alloc_mem(mp + p, &mem);
            mem[mp + p] += v * d;
          }
        }
      }

    }
  }
}

int main(int argc, char* argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <bf>\n", argv[0]);
    return 1;
  }

  const char* fname = argv[1];
  FILE* fp = fopen(fname, "rb");
  if (!fp) {
    perror("open");
    return 1;
  }
  string buf;
  while (true) {
    int c = fgetc(fp);
    if (c == EOF)
      break;
    buf += c;
  }
  fclose(fp);

  vector<Op*> ops;
  parse(buf.c_str(), &ops);
  run(ops);
}
