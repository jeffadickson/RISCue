// Single-ported reference SRAM endpoint, synchronous response, physical interleaving
// is a TARGET obligation, not implied by this RTL array.
module ft_ecc_ram #(
 parameter integer WORDS=1024,
 parameter INIT_FILE="",
 parameter bit FI_ENABLE=0
)(input logic clk,rst_n,req,
 input logic [38:0] addr_code,wdata_code,ctrl_code,
 output logic ready,error,
 output logic [38:0] rdata_code,
 output logic corrected_event,fatal,disagreement_event,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output logic fi_ack,
 output logic [7:0] event_flags,output logic [31:0] event_address);
 import ft_pkg::*;
 typedef struct packed {logic ready,error,fatal;logic [31:0] scrub;} ram_ctrl_t;
 (* keep = "true" *) ram_ctrl_t s0,s1,s2;
 ram_ctrl_t voted,next;
 logic [38:0] mem[0:WORDS-1];
 logic [31:0] image[0:WORDS-1];
 ecc_result_t ac,wc,cc,dc,sc;
 logic [31:0] ctrl_bits,data_bits;
 logic write_mem;integer index,byte_i,i;logic [31:0] merged;logic [38:0] write_code;
 initial begin
  for(i=0;i<WORDS;i=i+1)begin image[i]=0;mem[i]=ecc_encode(0);end
  if(INIT_FILE!="")begin $readmemh(INIT_FILE,image);for(i=0;i<WORDS;i=i+1)mem[i]=ecc_encode(image[i]);end
 end
 always @* begin
  voted=(s0&s1)|(s0&s2)|(s1&s2);next=voted;next.ready=0;next.error=0;
  ready=voted.ready;error=voted.error;fatal=voted.fatal;
  disagreement_event=(s0!=s1)||(s0!=s2)||(s1!=s2);
  ac=ecc_decode(addr_code);wc=ecc_decode(wdata_code);cc=ecc_decode(ctrl_code);
  ctrl_bits=cc.data;data_bits=wc.data;
  event_flags=0;event_address=0;
  fi_ack=FI_ENABLE&&fi_valid&&((fi_target==8&&fi_index<WORDS)||(fi_target>=9&&fi_target<=11));
  index=0;dc='0;sc='0;merged=0;write_mem=0;write_code=ecc_encode(0);corrected_event=0;
  if(!voted.fatal)begin
   if(req&&!voted.ready)begin
    next.ready=1;
    if(ac.uncorrectable||cc.uncorrectable||ac.data[1:0]!=0||ac.data[31:2]>=WORDS||cc.data[31:5]!=0)next.error=1;
    else begin
     index=ac.data[31:2];dc=ecc_decode(mem[index]);
     corrected_event=ac.corrected|cc.corrected;
     if(cc.data[4])begin
      if(wc.uncorrectable||(cc.data[3:0]!=4'b1111&&dc.uncorrectable))next.error=1;
      else begin
       merged=dc.data;
       for(byte_i=0;byte_i<4;byte_i=byte_i+1)if(ctrl_bits[byte_i])merged[byte_i*8+:8]=data_bits[byte_i*8+:8];
       write_mem=1;write_code=ecc_encode(merged);
       corrected_event=corrected_event|wc.corrected|(dc.corrected&&cc.data[3:0]!=4'b1111);
      end
     end else begin
      if(cc.data[3:0]!=0||dc.uncorrectable)next.error=1;
      else if(dc.corrected)begin write_mem=1;write_code=dc.repaired;corrected_event=1;end
     end
    end
   end else if(!req&&!voted.ready)begin
    if(voted.scrub>=WORDS)begin next.fatal=1;end
    else begin
     index=voted.scrub;sc=ecc_decode(mem[index]);
     if(sc.uncorrectable)next.fatal=1;
     else if(sc.corrected)begin write_mem=1;write_code=sc.repaired;corrected_event=1;end
     next.scrub=(voted.scrub==WORDS-1)?0:voted.scrub+1;
    end
   end
  end
  if(corrected_event)begin event_flags[0]=1;event_address=index*4;end
  if(next.error&&!voted.error)begin event_flags[1]=1;event_address=ac.data;end
  if(disagreement_event)begin event_flags[2]=1;event_address=voted.scrub*4;end
  if(next.fatal&&!voted.fatal)begin event_flags[3]=1;event_address=voted.scrub*4;end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin s0<='0;s1<='0;s2<='0;rdata_code<=ecc_encode(0);end
  else begin
   s0<=next;s1<=next;s2<=next;
   if(req&&!voted.ready&&!voted.fatal)rdata_code<=next.error?ecc_encode(0):dc.repaired;
   if(write_mem)mem[index]<=write_code;
   if(fi_ack)case(fi_target)
    8:mem[fi_index]<=((write_mem&&index==fi_index)?write_code:mem[fi_index])^fi_mask[38:0];
    9:s0<=next^fi_mask[$bits(ram_ctrl_t)-1:0];
    10:s1<=next^fi_mask[$bits(ram_ctrl_t)-1:0];
    11:s2<=next^fi_mask[$bits(ram_ctrl_t)-1:0];
   endcase
  end
 end
endmodule
