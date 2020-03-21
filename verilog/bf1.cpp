#include <iostream>
#include <fstream>
#include <bitset>

#include "Vbf1.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define CADDR_WIDTH 13
#define DADDR_WIDTH 15
#define DATA_WIDTH 8
#define STACK_DEPTH 4
#define MEMSIZE (1<<13)

using namespace std;

void print(Vbf1& top, int i) {
  if (top.clk) {
    // We set values before negative edge (we are so kind...)
    cout << "i=" << i
         << " insn=" << bitset<8>(top.insn)
         << " mem_din=" << bitset<DATA_WIDTH>(top.mem_din)
         << endl;
  } else {
    // CPU output is computed before positive edge
    cout << "    code_addr=" << bitset<CADDR_WIDTH>(top.code_addr)
         << " mem_addr=" << bitset<DADDR_WIDTH>(top.mem_addr)
         << " mem_wr=" << bitset<1>(top.mem_wr);
    if (top.mem_wr) {
      cout << " mem_dout=" << bitset<DATA_WIDTH>(top.mem_dout);
    }
    cout << endl;

    cout << "    io_wr=" << bitset<1>(top.io_wr);
    if (top.io_wr) {
      cout << " io_dout=" << bitset<DATA_WIDTH>(top.io_dout)
           << " (" << (char)top.io_dout << ")";
    }
    cout << endl;
  }
}

char *code;
streampos size;

unsigned char mem[MEMSIZE];
bool verbose = false;

int main(int argc, char **argv, char **env) {
  int clk;
  if (argc <= 1) {
    cout << "Give me program name!" << endl;
    exit(1);
  }

  Verilated::commandArgs(argc, argv);
  const char *verboseParam = Verilated::commandArgsPlusMatch("verbose");
  verbose = verboseParam && verboseParam[0];
  // init top verilog instance
  Vbf1 top;

  ifstream prog;
  prog.open(argv[1], ios::in | ios::binary | ios::ate);
  if (prog.is_open()) {
    size = prog.tellg();
    code = new char[size];
    prog.seekg (0, ios::beg);
    prog.read (code, size);
    prog.close();
  } else {
    return 1;
  }

  cout << "Program size is " << size << endl;

  // initialize simulation inputs
  top.resetq = 0;
  top.clk = 1;
  top.eval();
  // top.clk = 0;
  // top.eval();
  // top.clk = 1;
  // top.eval();

  int code_addr = 0;
  int mem_addr = 0;

  top.resetq = 1;
  unsigned long i = 0;
  do {
    // Write to CPU
    top.insn = code[code_addr];
    top.mem_din = mem[mem_addr];
    if (verbose)
      print(top, i);
    // cout << " -- <NEGedge>" << endl;
    top.clk = 0;
    top.eval(); // negedge [here everything should be calculated]

    // Read from CPU
    // values need to be stable before posedge, so we read them here
    code_addr = top.code_addr;
    mem_addr = top.mem_addr;
    if (mem_addr < 0 || mem_addr >= MEMSIZE) {
      cout << "i = " << i << endl;
      cout << "Memory out of range " << mem_addr << endl;
      exit(2);
    }
    if (top.mem_wr)
      mem[mem_addr] = top.mem_dout;
    if (top.io_wr)
      cout << (char)top.io_dout << flush;
    if (verbose)
      print(top, i);
    // cout << " -- <POSedge>" << endl;
    top.clk = 1;
    top.eval(); // posedge [outputs are available here]
    ++i;
  } while (code_addr < size && !Verilated::gotFinish());

  cout << endl << "Executed " << i << " instructions." << endl;

  delete[] code;
  exit(0);
}
