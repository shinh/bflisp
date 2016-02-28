BfLisp
=======

Lisp implementation in Brainfuck

[bflisp.bf](https://github.com/shinh/bflisp/blob/master/bflisp.bf)
is a Lisp interpreter in Brainfuck. This Brainfuck code is generated
from
[lisp.c](https://github.com/shinh/bflisp/blob/master/lisp.c)
by [modified 8cc](https://github.com/shinh/8cc/tree/bfs).


How to Use
----------

    $ make out/bfopt
    $ out/bfopt test/hello.bf  # check if bfopt is a valid BF interpreter
    Hello, world!
    $ echo 2038 01 | out/bfopt test/cal.bf  # check once more
                    1  2
     3  4  5  6  7  8  9
    10 11 12 13 14 15 16
    17 18 19 20 21 22 23
    24 25 26 27 28 29 30
    31
    $ out/bfopt bflisp.bf
    > (car (quote (a b c)))
    a
    > (cdr (quote (a b c)))
    (b c)
    > (cons 1 (cons 2 (cons 3 ())))
    (1 2 3)
    > (defun fact (n) (if (eq n 0) 1 (* n (fact (- n 1)))))
    (lambda (n) (if (eq n 0) 1 (* n (fact (- n 1)))))
    > (fact 4)
    24
    > (defun fib (n) (if (eq n 1) 1 (if (eq n 0) 1 (+ (fib (- n 1)) (fib (- n 2))))))
    (lambda (n) (if (eq n 1) 1 (if (eq n 0) 1 (+ (fib (- n 1)) (fib (- n 2))))))
    > (fib 4)
    5
    > (defun gen (n) ((lambda (x y) y) (define G n) (lambda (m) (define G (+ G m)))))
    (lambda (n) ((lambda (x y) y) (define G n) (lambda (m) (define G (+ G m)))))
    > (define x (gen 100))
    (lambda (m) (define G (+ G m)))
    > (x 10)
    110
    > (x 90)
    200
    > (x 300)
    500


Builtin Functions
-----------------

- car
- cdr
- cons
- eq
- atom
- +, -, *, /, mod
- neg?
- print


Special Forms
-------------

- quote
- if
- lambda
- defun
- define


How?
----

The modified 8cc (a small but full featured C compiler) outputs
assembly code for a virtual 16bit Harvard architecture CPU I
defined. The CPU has only a handful instructions - mov, add, sub,
load, store, comparison, conditional jumps, putc, getc, and exit. See
the top comment in
[bfasm.rb](https://github.com/shinh/bflisp/blob/master/bfasm.rb)
or [test/*.bfs](https://github.com/shinh/bflisp/tree/master/test)
for the detail.

Then, [bfcore.rb](https://github.com/shinh/bflisp/blob/master/bfcore.rb)
translates the assembly code to Brainfuck code. The
CPU has seven 16bit registers and they are consist of two memory cells
in 8bit Brainfuck (btw, I believe 8bit Brainfuck is the best choice for
this project). For each cycle, a big (~10k-way for bflisp.bf) switch
statement in Brainfuck is executed and each case statement represents
the virtual CPU instruction.

Memory operations are done by a loop which finds a corresponding row
using the higher 8bits and a 256-way switch statement for the lower
8bits. The memory module consumes ~1MB Brainfuck code space.

As the resulted Brainfuck code is big, bfopt.cc was developed. This
implementation merges consecutive +- and <>. This also optimizes
simple loops with balanced <>.

To make debugging easier, there's a simulator for the virtual CPU
(bfsim.rb). Lisp on the virtual CPU simulator is much faster than
Lisp on the virtual CPU implemented in Brainfuck. You can use
"./bfsim.rb bflisp.bfs" instead of "opt/bfopt bflisp.bf" for faster
execution.

    echo '(+ 3 4)' | ./bfsim.rb bflisp.bfs
    > 7


More Complicated Examples
-------------------------

You can test a few more examples.

FizzBuzz (took ~4 mins for me):

    $ cat fizzbuzz.l | opt/bfopt bflisp.bf
    (lambda (n) (if (eq n 101) nil (if (print (if (eq (mod n 15) 0) FizzBuzz (if (eq (mod n 5) 0) Buzz (if (eq (mod n 3) 0) Fizz n)))) (fizzbuzz (+ n 1)) nil)))
    1
    2
    Fizz
    ...
    98
    Fizz
    Buzz
    nil

Sort (took ~3 mins for me):

    $ cat sort.l | opt/bfopt bflisp.bf
    ...
    (1 2 3 4 5 6 7)


Limitations
-----------

There should be a lot of limitations. bflisp behaves very strangely
when you pass a broken Lisp code.

bflisp.bf should run on any 8bit Brainfuck implementations. However,
only optimized implementation can run the Lisp interpreter.
[bff4.c](http://mazonka.com/brainf/) is an implementation which can
run bflisp.bf with little modification (see bff4.patch).


TODO
----

* Run 8cc on Brainfuck.
* Implement the virtual CPU with other esoteric language.
* Fix bugs.


See also
--------

* [Lisp in sed](https://github.com/shinh/sedlisp)
* [Lisp in Befunge](https://github.com/shinh/beflisp)
* [Lisp in GNU make](https://github.com/shinh/makelisp)


Acknowledgement
---------------

I'd like to thank [Rui Ueyama](https://github.com/rui314/) for his
easy-to-hack compiler and suggesting the basic idea which made this
possible.
