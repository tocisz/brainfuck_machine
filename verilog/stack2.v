`default_nettype none

module stack2
#(
  parameter DEPTH=16,
  parameter WIDTH=16
)
(
  input wire clk,
  input wire we,
  input wire [1:0] delta,
  output wire [WIDTH-1:0] rd,
  input  wire [WIDTH-1:0] wd
);
  localparam BITS = (WIDTH * DEPTH) - 1;

  wire move = delta[0];

  reg [WIDTH-1:0] head;
  reg [BITS:0] tail;
  wire [WIDTH-1:0] headN;
  wire [BITS:0] tailN;

  assign headN = we ? wd : tail[WIDTH-1:0];
  assign tailN = delta[1] ? {{WIDTH{1'b0}}, tail[BITS:WIDTH]} : {tail[BITS-WIDTH:0], head};

  always @(posedge clk) begin
    if (we | move)
      head <= headN;
    if (move)
      tail <= tailN;
  end

  assign rd = head;

`ifdef VERILATOR
  int depth /* verilator public_flat */;
  always @(posedge clk) begin
    if (delta == 2'b11)
      depth <= depth - 1;
    if (delta == 2'b01)
      depth <= depth + 1;
  end
`endif

endmodule
