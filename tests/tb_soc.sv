module tb_soc;
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire halted,fatal,trap,ce,de,rv;wire [31:0] cause,tval,pc,rpc,ri,rr;wire [4:0] rd;
 rv32im_ft_soc #(.WORDS(256)) dut(.clk(clk),.rst_n(rst_n),.halted(halted),.fatal(fatal),.trap(trap),.trap_cause(cause),.trap_value(tval),.pc(pc),.corrected_event(ce),.disagreement_event(de),.retire_valid(rv),.retire_pc(rpc),.retire_insn(ri),.retire_result(rr),.retire_rd(rd),.fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0));
 integer cycles,retires;
 task emit(input integer loc,input logic [31:0] insn);begin dut.ram.mem[loc]=ecc_encode(insn);end endtask
 function automatic logic [31:0] addi(input integer rd,rs,imm);addi=((imm&4095)<<20)|(rs<<15)|(rd<<7)|32'h13;endfunction
 function automatic logic [31:0] rtype(input integer f3,rd,rs1,rs2);rtype=(1<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|32'h33;endfunction
 task regcheck(input integer r,input logic [31:0] expected);ecc_result_t d;begin d=ecc_decode(dut.core.rf[r]);if(d.data!==expected||d.uncorrectable)$fatal(1,"x%0d=%h expected=%h",r,d.data,expected);end endtask
 initial begin
  #1;
  emit(0,addi(1,0,512));emit(1,addi(2,0,-7));emit(2,addi(3,0,3));
  emit(3,rtype(0,4,2,3));emit(4,rtype(4,5,2,3));emit(5,rtype(6,6,2,3));
  emit(6,32'h0040a023); // sw x4,0(x1)
  emit(7,32'h0000a383); // lw x7,0(x1)
  emit(8,32'h007080a3); // sb x7,1(x1)
  emit(9,32'h00108403); // lb x8,1(x1)
  emit(10,32'h0010c483); // lbu x9,1(x1)
  emit(11,32'h00009503); // lh x10,0(x1)
  emit(12,32'h0000d583); // lhu x11,0(x1)
  emit(13,addi(12,0,5));emit(14,addi(13,0,0));
  emit(15,addi(13,13,1));emit(16,addi(12,12,-1));
  emit(17,32'hfe061ce3); // bne x12,x0,-8
  emit(18,32'h0080076f); // jal x14,+8
  emit(19,addi(13,0,99));emit(20,addi(15,0,0));
  emit(21,32'h00100073);
  repeat(2)@(negedge clk);rst_n=1;cycles=0;retires=0;
  while(!halted&&cycles<1000)begin @(negedge clk);cycles=cycles+1;if(rv)retires=retires+1;end
  if(!halted||fatal||!trap||cause!=3||pc!=84)$fatal(1,"termination pc=%h cause=%h fatal=%b",pc,cause,fatal);
  regcheck(0,0);regcheck(4,32'hffffffeb);regcheck(5,32'hfffffffe);regcheck(6,32'hffffffff);
  regcheck(7,32'hffffffeb);regcheck(8,32'hffffffeb);regcheck(9,235);regcheck(10,32'hffffebeb);regcheck(11,32'hebeb);
  regcheck(12,0);regcheck(13,5);regcheck(14,76);regcheck(15,0);
  $display("PASS SoC: compiled-style loop, M operations, loads/stores, subword sign extension, JAL, trap; %0d cycles",cycles);$finish;
 end
endmodule
