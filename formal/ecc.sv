module formal_ecc;
 import ft_pkg::*;
 (* anyconst *) reg [31:0] data;
 (* anyconst *) reg [5:0] bit_a,bit_b;
 wire [38:0] clean=ecc_encode(data);
 ecc_result_t c,s,d;
 always @* begin
  assume(bit_a<39);assume(bit_b<39);assume(bit_a!=bit_b);
  c=ecc_decode(clean);
  s=ecc_decode(clean^(39'b1<<bit_a));
  d=ecc_decode(clean^(39'b1<<bit_a)^(39'b1<<bit_b));
  assert(c.data==data && c.repaired==clean && !c.corrected && !c.uncorrectable);
  assert(s.data==data && s.repaired==clean && s.corrected && !s.uncorrectable);
  assert(d.uncorrectable && !d.corrected);
 end
endmodule
