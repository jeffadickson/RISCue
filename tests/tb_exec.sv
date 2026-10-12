module tb_exec;
 import ft_pkg::*;
 logic [31:0] insn,pc,a,b,expected;exec_t e;integer fd,count,rc;
 rv32_execute dut(insn,pc,a,b,e);
 task check(input logic condition,input string message);begin if(!condition)$fatal(1,"%s insn=%h a=%h b=%h result=%h expected=%h",message,insn,a,b,e.result,expected);end endtask
 initial begin
  pc=32'h100;count=0;fd=$fopen("build/exec_vectors.txt","r");if(!fd)$fatal(1,"missing vectors");
  while(!$feof(fd))begin
   rc=$fscanf(fd,"%h %h %h %h\n",insn,a,b,expected);
   if(rc==4)begin #1;check(!e.trap&&e.rd_we&&e.result===expected,"arithmetic");count=count+1;end
  end
  $fclose(fd);
  // All six branch comparisons, both signedness and taken/untaken paths.
  for(integer f=0;f<8;f=f+1)if(f!=2&&f!=3)begin
   for(integer n=0;n<3;n=n+1)begin
    a=(n==0)?32'hffffffff:32'd2;b=(n==1)?32'd2:32'd1;
    insn=(f<<12)|(1<<15)|(2<<20)|32'h00000463;#1;
    case(f)
     0:check(e.next_pc==((a==b)?32'h108:32'h104),"BEQ");
     1:check(e.next_pc==((a!=b)?32'h108:32'h104),"BNE");
     4:check(e.next_pc==(($signed(a)<$signed(b))?32'h108:32'h104),"BLT");
     5:check(e.next_pc==(($signed(a)>=$signed(b))?32'h108:32'h104),"BGE");
     6:check(e.next_pc==((a<b)?32'h108:32'h104),"BLTU");
     7:check(e.next_pc==((a>=b)?32'h108:32'h104),"BGEU");
    endcase
   end
  end
  insn=32'h00000037;#1;check(e.result==0&&e.rd_we,"LUI");
  insn=32'h00001097;#1;check(e.result==32'h1100,"AUIPC");
  insn=32'h008001ef;#1;check(e.result==32'h104&&e.next_pc==32'h108,"JAL");
  insn=32'h000081e7;a=32'h109;#1;check(e.next_pc==32'h108,"JALR bit0 clear");
  a=32'h102;#1;check(e.trap&&e.cause==0&&!e.rd_we,"misaligned jump");
  a=1;insn=32'h00009183;#1;check(e.trap&&e.cause==4&&!e.mem,"misaligned LH");
  insn=32'h0020a023;#1;check(e.trap&&e.cause==6&&!e.mem,"misaligned SW");
  insn=32'h0000000f;#1;check(!e.trap,"FENCE");
  insn=32'h00000073;#1;check(e.trap&&e.cause==11,"ECALL");
  insn=32'h00100073;#1;check(e.trap&&e.cause==3,"EBREAK");
  insn=32'hffffffff;#1;check(e.trap&&e.cause==2,"illegal");
  insn=32'h02009193;#1;check(e.trap&&e.cause==2,"illegal shift");
  $display("PASS execution: %0d arithmetic vectors + branches/jumps/traps",count);$finish;
 end
endmodule
