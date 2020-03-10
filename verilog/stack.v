`include "common.h"

module stack
  #(
    parameter DEPTH=4,
    parameter WIDTH=16
  )
  (input wire clk,
  /* verilator lint_off UNUSED */
  input wire resetq,
  /* verilator lint_on UNUSED */
  input wire [DEPTH-1:0] ra,
  output wire [WIDTH-1:0] rd,
  input wire we,
  input wire [DEPTH-1:0] wa,
  input wire [WIDTH-1:0] wd);

  reg [WIDTH-1:0] store[0:(2**DEPTH)-1];
  /* verilator lint_off UNUSED */
  reg [100:0] verbose;
  /* verilator lint_on UNUSED */

  always @(posedge clk)
    if (we) begin
      store[wa] <= wd;
      if ($value$plusargs("verbose", verbose))
        $write(" -- Stack write ", wd, " at ", wa, "\n");
    end

  assign rd = store[ra];
endmodule
