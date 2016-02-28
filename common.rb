RUNNING = 0
PC = 1
NPC = 5
A = 9
B = 13
C = 17
D = 21
BP = 25
SP = 29
OP = 33

WRK = 40

LOAD_REQ = 44
STORE_REQ = 45

MEM = 50
MEM_V = 0
MEM_A = 2
MEM_WRK = 4
MEM_CTL_LEN = 8
MEM_BLK_LEN = 512 + MEM_CTL_LEN

def sym?(o)
  o.class == Symbol
end

def error(loc, msg)
  filename, lineno, column, len = *loc
  r = "#{filename}:#{lineno}:#{column}"
  if len > 1
    r += "-#{column+len-1}"
  end
  STDERR.puts("#{r}: #{msg}")
  exit 1
end

if ARGV[0] == '-v'
  $verbose = true
  ARGV.shift
end
