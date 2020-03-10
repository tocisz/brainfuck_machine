// Example from
// http://rattus-pubis.blogspot.no/2011/02/experimenting-with-verilator-counter.html
//

#include <iostream>
#include <bitset>

#include "Vstack.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

void print(Vstack& top, int i) {
  if (top.clk == 1) {
    std::cout << "i=" << i
      << " data=" << std::bitset<32>(top.rd)
      << std::endl;
  }
}

int main(int argc, char **argv, char **env) {
  int i;
  int clk;
  Verilated::commandArgs(argc, argv);
  // init top verilog instance
  Vstack top;
  // initialize simulation inputs
  top.clk = 1;

  // write
  std::cout << "Write" << std::endl;
  for (i=0; i < 10; i++) {
    top.clk = 0;
    top.we = 1;
    top.wa = i;
    top.wd = i*16;
    top.eval();
    top.clk = 1;
    top.eval();
    print(top, i);
    if (Verilated::gotFinish())  exit(0);
  }

  // read
  std::cout << "Read" << std::endl;
  for (i=9; i >= 0; i--) {
    top.clk = 0;
    top.we = 0;
    top.ra = i;
    top.eval();
    top.clk = 1;
    top.eval();
    print(top, i);
    if (Verilated::gotFinish())  exit(0);
  }

  exit(0);
}
