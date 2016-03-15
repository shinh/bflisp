CXXFLAGS := -O -g -std=gnu++11 -Wall -W -Werror

CFLAGS := -I. -fno-builtin -m32
CFLAGS += -Wall -W -Werror -Wno-unused-function
CLANGFLAGS := $(CFLAGS) -Wno-incompatible-library-redeclaration

BFS_SRCS :=

BFS_ASMS := $(wildcard test/*.bfs)
BFS_ASMS_STAGED := $(BFS_ASMS:test/%.bfs=out/%.bfs)
BFS_SRCS += $(BFS_ASMS_STAGED)

BFS_RBS := $(wildcard test/*.bfs.rb)
BFS_RBS_STAGED := $(BFS_RBS:test/%.bfs.rb=out/%.bfs)
BFS_SRCS += $(BFS_RBS_STAGED)

BFS_CS := $(wildcard test/*.c)
ifndef BFS24
BFS_CS := $(filter-out test/24_%.c, $(BFS_CS))
endif

BFS_CS_STAGED := $(BFS_CS:test/%.c=out/%.bfs)
TEST_EXES := $(BFS_CS:test/%.c=out/%.exe)
TEST_RES := $(TEST_EXES:%.exe=%.res)
TEST_OKS := $(TEST_EXES:%.exe=%.ok1)

#BFS_CS := $(wildcard test/*.c)
#BFS_ASMS := $(BFS_CS:test/%.c=out/%.s)
#BFS_OBJS := $(BFS_CS:test/%.c=out/%.o)
#BFS_CS_STAGED := $(BFS_OBJS:%.o=%.bfs)
BFS_SRCS += $(BFS_CS_STAGED)

BFS_BFS := $(BFS_SRCS:%.bfs=%.bf)
BFS_SIMS := $(BFS_SRCS:%.bfs=%.sim)
BFS_OUTS := $(BFS_SRCS:%.bfs=%.out)
BFS_OKS := $(BFS_SRCS:%.bfs=%.ok2)

# Very slow.
BFS_OKS_RUN := $(BFS_OKS)
BFS_OKS_RUN := $(filter-out out/fizzbuzz.ok2, $(BFS_OKS_RUN))

RUBY_DEPS := $(wildcard bf*.rb) common.rb Makefile

LISP_BFS := out/lisp.bfs
LISP_BF := out/lisp.bf

8CC_C := out/8cc.c
8CC_BFS := out/8cc.bfs
8CC_BF := out/8cc.bf
8CC_BF_C := out/8cc.bf.c
8CC_BF_EXE := out/8cc.bf.exe

ALL := $(BFS_BFS) $(BFS_SIMS) $(BFS_OKS_RUN)
ALL += $(BFS_OBJS) $(BFS_ASMS)
ALL += 8cc/8cc
ALL += $(TEST_OKS)
ALL += $(LISP_BFS)
ALL += out/bfopt $(LISP_BF)

$(shell mkdir -p out)

all: $(ALL)

define run-diff
@if diff -uN $1 $2 > $@.tmp; then \
  echo PASS: "$*.bfs($3)"; \
  mv $@.tmp $@; \
else \
  echo FAIL: "$*.bfs($3)"; \
  cat $@.tmp; \
fi
endef

$(BFS_ASMS_STAGED): out/%.bfs: test/%.bfs
	cp $< $@.tmp && mv $@.tmp $@

$(BFS_RBS_STAGED): out/%.bfs: test/%.bfs.rb
	ruby $< > $@.tmp && mv $@.tmp $@

$(BFS_CS_STAGED): out/%.bfs: test/%.c 8cc/8cc libf.h
	8cc/8cc -S -o $@.tmp $< && mv $@.tmp $@

$(BFS_BFS): %.bf: %.bfs $(RUBY_DEPS)
	./bfcore.rb $< > $@.tmp && mv $@.tmp $@

$(BFS_SIMS): %.sim: %.bfs $(RUBY_DEPS) run.sh
	./run.sh ./bfsim.rb -q $< > $@.tmp && mv $@.tmp $@

$(BFS_OUTS): %.out: %.bf run.sh out/bfopt
	./run.sh out/bfopt $< > $@.tmp && mv $@.tmp $@

$(BFS_OKS): %.ok2: %.sim %.out
	$(call run-diff,$*.sim,$*.out,sim:bf)

$(TEST_EXES): out/%.exe: test/%.c libf.h
	$(CC) -fno-builtin -g -o $@ $<

$(TEST_RES): %.res: %.exe run.sh
	./run.sh $< $*.bfs > $@.tmp && mv $@.tmp $@

$(TEST_OKS): %.ok1: %.res %.sim
	$(call run-diff,$*.res,$*.sim,gcc:8cc)

$(LISP_BFS): lisp.c 8cc/8cc libf.h
	8cc/8cc -S -o $@.tmp $< && mv $@.tmp $@

$(LISP_BF): $(LISP_BFS)
	./bfcore.rb $< > $@.tmp && mv $@.tmp $@

$(8CC_C): 8cc/8cc merge_8cc.sh
	./merge_8cc.sh > $@.tmp && mv $@.tmp $@

$(8CC_BFS): out/8cc.c 8cc/8cc libf.h
	8cc/8cc -S -o $@.tmp $< && mv $@.tmp $@

$(8CC_BF): $(8CC_BFS)
	./bfcore.rb $< > $@.tmp && mv $@.tmp $@

$(8CC_BF_C): $(8CC_BF) out/bfopt
	out/bfopt -c $< $@.tmp && mv $@.tmp $@

$(8CC_BF_EXE): $(8CC_BF_C)
	$(CC) $< -o $@

out/bfopt: bfopt.cc
	$(CXX) $(CXXFLAGS) $< -o $@

.PHONY: all
.SUFFIXES:

8cc/8cc: $(wildcard 8cc/*.c 8cc/*.h) 8cc/README.md
	$(MAKE) -C 8cc

8cc/README.md:
	rm -fr 8cc.tmp
	git clone https://github.com/shinh/8cc.git 8cc.tmp
	cd 8cc.tmp && git checkout bfs
	mv 8cc.tmp 8cc
