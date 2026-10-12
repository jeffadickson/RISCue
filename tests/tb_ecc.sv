module tb_ecc;
 import ft_pkg::*;
 ecc_result_t r;logic [38:0] c,e;logic [31:0] data;integer n,i,j,total;
 initial begin
  total=0;
  for(n=0;n<12;n=n+1)begin
   data=$random;c=ecc_encode(data);r=ecc_decode(c);
   if(r.data!==data||r.corrected||r.uncorrectable)$fatal(1,"clean ECC");
   for(i=0;i<39;i=i+1)begin
    e=c^(39'b1<<i);r=ecc_decode(e);
    if(r.data!==data||!r.corrected||r.uncorrectable||r.repaired!==c)$fatal(1,"single bit %0d",i);
    total=total+1;
    for(j=i+1;j<39;j=j+1)begin
     e=c^(39'b1<<i)^(39'b1<<j);r=ecc_decode(e);
     if(!r.uncorrectable||r.corrected)$fatal(1,"double bits %0d %0d",i,j);
     total=total+1;
    end
   end
  end
  $display("PASS ECC: %0d single/double bit injections",total);$finish;
 end
endmodule
