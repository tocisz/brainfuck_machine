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
   output wire [`DATA_WIDTH-1:0] io_dout,
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
   wire [`CADDR_WIDTH-1:0] rstkD;   // R stack write value
   wire [`CADDR_WIDTH-1:0] rst0;
   stack #(.DEPTH(`DEPTH),.WIDTH(`CADDR_WIDTH)) rstack (
     .clk(clk),
     .ra(rsp),
     .rd(rst0),
     .we(rstkW),
     .wa(rspN),
     .wd(rstkD)
   );

   // ALU
   reg alu_op;
   reg [`DADDR_WIDTH-1:0] alu_a;
   reg [`CADDR_WIDTH-1:0] alu_b;
   reg [`DADDR_WIDTH-1:0] alu_c;

   reg lj, ljN;
   reg  [4:0] lj_offset;
   wire [4:0] lj_offsetN;

   // before ALU
   always @(maddr, insn, mem_din, lj, lj_offset, pc)
   begin
     alu_op =  1'bX; // don't care
     alu_a  = 15'bX; // let synthesis decide what takes least resources
     alu_b  = 13'bX;
     casez ({lj,insn[7:6]})
       3'b0_00: begin alu_op = insn[5]; alu_a = maddr;                 alu_b = {8'b0,insn[4:0]}; end
       3'b0_01: begin alu_op = insn[5]; alu_a = {7'b0,mem_din};        alu_b = {8'b0,insn[4:0]}; end
       3'b1_??: begin alu_op = 0;       alu_a = {2'b0,lj_offset,insn}; alu_b = pc; end
       3'b0_10: begin alu_op = 0;       alu_a = {10'b0,insn[4:0]};     alu_b = pc; end
       3'b0_11: ; // ALU not used
     endcase
   end

   // ALU
   always @(alu_op, alu_a, alu_b)
   begin
    if (alu_op) // simplify?
      alu_c = alu_a - {2'b0,alu_b} - 1'b1;
    else
      alu_c = alu_a + {2'b0,alu_b} + 1'b1;
   end

   reg do_jump_or_ret;
   reg do_jump;

   // after ALU
   assign io_dout = mem_din; // nothing else can go as IO output
   always @(pc, maddr, insn, alu_c, io_din, lj)
   begin
     // defaults
     mem_wr = 0;
     io_wr  = 0;
     ljN = 0;
     maddrN = maddr;
	   mem_dout = io_din; // default that can be overriden
     do_jump_or_ret = 0;
     do_jump = 0;

     casez ({lj,insn[7:5]})
       4'b0_00?: begin   maddrN = alu_c; end
       4'b0_01?: begin mem_dout = alu_c[7:0]; mem_wr = 1; end
       4'b0_100: begin do_jump_or_ret = 1; do_jump = |insn[4:0]; end // [ or ]
       4'b1_???: begin do_jump_or_ret = 1; do_jump = 1; end // do long jump
       4'b0_101: begin     ljN = 1; end // begin long jump
       4'b0_110: begin  mem_wr = 1; end // , (sync signal?)
       4'b0_111: begin   io_wr = 1; end // .
     endcase
   end

   // calculate pc
   assign rstkD = pcN; // if we put anything on stack, it's pcN
   assign lj_offsetN = insn[4:0]; // remember offset from previous instruction
   always @ (do_jump_or_ret, do_jump, pc, mem_din, rsp, rst0, alu_c)
   begin
     // default: go to the next instruction
     pcN   = pc + 1'b1;
     rspN  = rsp;
     rstkW = 0;

     if (do_jump_or_ret)
     begin
       if (do_jump)
       begin // [
         if (mem_din != 0) begin
           rspN = rsp + 1'b1; // into the loop
           rstkW = 1;
         end else begin
           pcN = alu_c[12:0]; // skip the loop
         end
       end
       else
       begin // ]
         if (mem_din != 0) pcN = rst0; // loop again
         else rspN = rsp - 1'b1; // leave the loop
       end
     end
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
