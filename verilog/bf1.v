`include "common.h"

module bf1 (
   input wire clk,
   input wire resetq,

   output wire [`DADDR_WIDTH-1:0] mem_addr,
   output reg  mem_wr,
   output reg  [`DATA_WIDTH-1:0] mem_dout,
   input  wire [`DATA_WIDTH-1:0] mem_din,

   output reg  io_wr,
   input  wire [`DATA_WIDTH-1:0] io_din,
   output reg  [`DATA_WIDTH-1:0] io_dout,
   // TODO wait for IO
   // input  wire io_in_ready
   // output wire io_in_ack

   output wire [`CADDR_WIDTH-1:0] code_addr,
   input  wire [7:0] insn,

   output wire [`DEPTH-1:0] _rsp
);

   // for debug only
   assign _rsp = rspN;

   reg [`CADDR_WIDTH-1:0] pc, pcN;
   assign code_addr = pcN; // output next value as soon as it propagates

   reg [`DADDR_WIDTH-1:0] maddr, maddrN; // Tape address
   assign mem_addr = maddrN; // output next value as soon as it propagates

   // Stack and stack variables
   reg [`DEPTH-1:0] rsp, rspN;
   reg rstkW = 0;                 // R stack write
   reg [`CADDR_WIDTH-1:0] rstkD;   // R stack write value
   wire [`CADDR_WIDTH-1:0] rst0;
   stack #(.DEPTH(`DEPTH),.WIDTH(`CADDR_WIDTH)) rstack (
     .clk(clk),
     .resetq(resetq),
     .ra(rsp),
     .rd(rst0),
     .we(rstkW),
     .wa(rspN),
     .wd(rstkD)
   );

   // ALU
   reg [`DADDR_WIDTH-1:0] alu_in;
   reg [5:0] alu_arg;
   reg [`DADDR_WIDTH-1:0] alu_out;

   reg lj, ljN;
   reg [4:0] lj_offset, lj_offsetN;

   // before ALU
   always @(maddr, insn, mem_din)
   begin
     // defaults
     alu_arg = insn[5:0];
     case (insn[7:6])
       2'b00: begin alu_in = maddr; end
       2'b01: begin alu_in = {7'b0,mem_din}; end
       default: ;
     endcase
   end

   // ALU
   always @(alu_in, alu_arg)
   begin
    if (alu_arg[5]) // simplify?
      alu_out = alu_in - {10'b0,alu_arg[4:0]} - 15'b1;
    else
      alu_out = alu_in + {10'b0,alu_arg[4:0]} + 15'b1;
   end

   // after ALU
   always @(pc, maddr, insn, alu_out, mem_din, rsp, rst0, lj, lj_offset)
   begin
     // defaults
     mem_wr = 0;
     rstkW  = 0;
     io_wr  = 0;
     ljN = 0;
     pcN = pc+1;
     maddrN = maddr;
     rspN = rsp;
     if (lj) // long jump second phase
       if (mem_din != 0) begin
         rspN = rsp+1; // into the loop [TODO factor out]
         rstkW = 1;
         rstkD = pcN;
       end else begin
         pcN = pc + {lj_offset,insn} + 13'b1; // TODO use ALU for that
       end
     else // normal instruction
       casez (insn[7:5])
         3'b00?: begin   maddrN = alu_out; end
         3'b01?: begin mem_dout = alu_out[7:0]; mem_wr = 1; end
         3'b100:
         if (|insn[4:0]) // [
           // mem_din can come with a delay...
           if (mem_din != 0) begin
               rspN = rsp+1; // into the loop
               rstkW = 1;
               rstkD = pcN;
               // $write(" -- Pushing ", rstkD, "\n");
           end else begin
              pcN = pc + {8'b0,insn[4:0]} + 13'b1; // skip the loop
           end
         else // ]
           if (mem_din != 0) pcN = rst0; // loop again
           else             rspN = rsp-1; // leave the loop
         3'b101: begin lj_offsetN = insn[4:0];   ljN = 1; end // begin long jump
         3'b110: begin   mem_dout = io_din;   mem_wr = 1; $finish(); end // , (sync signal?)
         3'b111: begin    io_dout = mem_din;   io_wr = 1; end // .
       endcase
   end

   always @(negedge resetq or posedge clk)
   begin
     if (!resetq) begin
       { pc, rsp, maddr, lj, lj_offset } <= 0;
     end else begin
       { pc, rsp, maddr, lj, lj_offset }
       <= { pcN, rspN, maddrN, ljN, lj_offsetN };
     end
   end

endmodule
