`timescale 1ns/1ps
module tb_bitmanip;
 import ft_pkg::*;
 logic [31:0] insn,a,b,expected;integer bad,fd,n,count;exec_t out;
 riscue_execute #(.COMPRESSED(1),.MULTICYCLE_M(1)) dut(.instruction_bytes(3'd4),.insn(insn),.pc(32'd0),.a(a),.b(b),.out(out));
 initial begin
  fd=$fopen("build/bitmanip_vectors.txt","r");if(!fd)$fatal(1,"vectors missing");count=0;
  while(!$feof(fd))begin
   n=$fscanf(fd,"%h %h %h %h %h\n",insn,a,b,expected,bad);
   if(n==5)begin
    #1;
    if(bad)begin
     if(!out.illegal||!out.trap||out.cause!=2||out.tval!=insn||out.rd_we||out.mem||out.we)$fatal(1,"reserved encoding accepted %h",insn);
    end else if(out.illegal||out.trap||!out.rd_we||out.result!==expected||out.next_pc!=4||out.rd!=3||out.mem||out.we)
     $fatal(1,"bitmanip %h a=%h b=%h got=%h expected=%h",insn,a,b,out.result,expected);
    count=count+1;
   end
  end
  $display("PASS bitmanip %0d vectors",count);$finish;
 end
endmodule
