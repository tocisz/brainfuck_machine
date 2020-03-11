`include "common.h"

module stack
  #(
    parameter DEPTH=4,
    parameter WIDTH=16
  )
  (input wire clk,
  input wire [DEPTH-1:0] ra,
  output wire [WIDTH-1:0] rd,
  input wire we,
  input wire [DEPTH-1:0] wa,
  input wire [WIDTH-1:0] wd);

  reg [WIDTH-1:0] store[0:(2**DEPTH)-1];
  /* verilator lint_off UNUSED */
  reg verbose;
  /* verilator lint_on UNUSED */

  always @(posedge clk)
    if (we) begin
      store[wa] <= wd;
      if ($value$plusargs("verbose", verbose))
        $display(" -- Stack write ", wd, " at ", wa);
    end

  assign rd = store[ra];
endmodule
