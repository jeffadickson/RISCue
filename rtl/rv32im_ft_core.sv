module rv32im_ft_core #(
 parameter logic [31:0] RESET_PC=0,
 parameter integer BUS_TIMEOUT=1024,
 parameter bit RF_TMR=0,
 parameter bit FI_ENABLE=0
)(
 input logic clk,rst_n,
 output logic req,
 output logic [38:0] addr_code,wdata_code,ctrl_code,
 input logic ready,bus_error,external_fault,
 input logic [38:0] rdata_code,
 output logic halted,fatal,trap,
 output logic [31:0] trap_cause,trap_value,pc,
 output logic corrected_event,disagreement_event,
 output logic retire_valid,
 output logic [31:0] retire_pc,retire_insn,retire_result,
 output logic [4:0] retire_rd,
 input logic fi_valid,
 input logic [3:0] fi_target,
 input logic [31:0] fi_index,
 input logic [511:0] fi_mask,
 output logic fi_ack,
 output logic [7:0] event_flags,
 output logic [31:0] event_address
`ifdef RISCV_FORMAL
 ,`RVFI_OUTPUTS
`endif
);
 import ft_pkg::*;
 // Replica placement and independent voters must be enforced by target implementation.
 (* keep = "true", DONT_TOUCH = "TRUE" *) control_t c0,c1,c2;
 control_t voted,next;
 (* keep = "true", DONT_TOUCH = "TRUE" *) logic [38:0] rf[0:31];
 ecc_result_t ar,br,sr,mr;
 (* keep = "true", DONT_TOUCH = "TRUE" *) logic [31:0] tmr0[0:31],tmr1[0:31],tmr2[0:31];
 function automatic ecc_result_t read_reg(input logic [4:0] idx);
  ecc_result_t r;
  begin
   r='0;
   if(idx!=0)begin
    if(RF_TMR)begin
     r.data=(tmr0[idx]&tmr1[idx])|(tmr0[idx]&tmr2[idx])|(tmr1[idx]&tmr2[idx]);
     r.corrected=(tmr0[idx]!=tmr1[idx])||(tmr0[idx]!=tmr2[idx]);
     r.repaired=ecc_encode(r.data);
    end else r=ecc_decode(rf[idx]);
   end
   read_reg=r;
  end
 endfunction
 task automatic repair_reg(input logic [4:0] idx,input ecc_result_t r);
  begin
   if(RF_TMR)begin tmr0[idx]<=r.data;tmr1[idx]<=r.data;tmr2[idx]<=r.data;end
   else rf[idx]<=r.repaired;
  end
 endtask
 task automatic write_reg(input logic [4:0] idx,input logic [31:0] value);
  begin
   if(RF_TMR)begin tmr0[idx]<=value;tmr1[idx]<=value;tmr2[idx]<=value;end
   else rf[idx]<=ecc_encode(value);
  end
 endtask
 (* keep = "true", DONT_TOUCH = "TRUE" *) exec_t e0,e1;
 exec_t pending;
 logic [31:0] load_word,load_result;
 logic [38:0] fi_rf_base;logic [31:0] fi_tmr_base0,fi_tmr_base1,fi_tmr_base2;
 integer i;
 (* keep_hierarchy = "yes", DONT_TOUCH = "TRUE" *) rv32_execute lane0(voted.insn,voted.pc,ar.data,br.data,e0);
 (* keep_hierarchy = "yes", DONT_TOUCH = "TRUE" *) rv32_execute lane1(voted.insn,voted.pc,ar.data,br.data,e1);
 always @* begin
  voted=(c0&c1)|(c0&c2)|(c1&c2);
  pending=voted.pending;
  ar=read_reg(voted.insn[19:15]);br=read_reg(voted.insn[24:20]);
  if(voted.insn[19:15]==0)ar='0;if(voted.insn[24:20]==0)br='0;
  sr=read_reg(voted.scrub);mr=ecc_decode(rdata_code);
  load_word=mr.data>>(pending.addr[1:0]*8);
  case(pending.load_kind)
   0:load_result={{24{load_word[7]}},load_word[7:0]};
   1:load_result={{16{load_word[15]}},load_word[15:0]};
   2:load_result=load_word;
   4:load_result={24'd0,load_word[7:0]};
   5:load_result={16'd0,load_word[15:0]};
   default:load_result=0;
  endcase
  next=voted;next.scrub=(voted.scrub==31)?5'd1:voted.scrub+1;
  req=0;addr_code=ecc_encode(0);wdata_code=ecc_encode(0);ctrl_code=ecc_encode(0);
  event_flags=0;event_address=0;
  fi_ack=FI_ENABLE&&fi_valid&&(((((!RF_TMR&&fi_target==1)||(RF_TMR&&fi_target>=2&&fi_target<=4)))&&fi_index<32)||(fi_target>=5&&fi_target<=7));
  retire_valid=0;retire_pc=voted.pc;retire_insn=voted.insn;retire_result=0;retire_rd=0;
  corrected_event=(sr.corrected&&voted.scrub!=0);
  disagreement_event=(c0!=c1)||(c0!=c2)||(c1!=c2);
  if(voted.state!=ST_HALT)begin
   case(voted.state)
    ST_FETCH:begin
     req=1;addr_code=ecc_encode(voted.pc);next.wait_count=voted.wait_count+1;
     if(ready)begin
      corrected_event=corrected_event|mr.corrected;
      if(bus_error||mr.uncorrectable)begin next.fatal=1;next.cause=32'h80000002;end
      else begin next.insn=mr.data;next.state=ST_EXEC;next.wait_count=0;end
     end
    end
    ST_EXEC:begin
     corrected_event=corrected_event|ar.corrected|br.corrected;
     if(ar.uncorrectable||br.uncorrectable)begin next.fatal=1;next.cause=32'h80000003;end
     else if(e0!=e1)begin next.fatal=1;next.cause=32'h80000004;end
     else if(e0.trap)begin next.trap=1;next.cause=e0.cause;next.tval=e0.tval;next.state=ST_HALT;end
     else if(e0.mem)begin next.pending=e0;next.state=ST_MEM;next.wait_count=0;end
     else begin
      retire_valid=1;retire_result=e0.result;retire_rd=e0.rd_we?e0.rd:0;
      next.pc=e0.next_pc;next.state=ST_FETCH;
     end
    end
    ST_MEM:begin
     req=1;addr_code=ecc_encode({pending.addr[31:2],2'b00});
     wdata_code=ecc_encode(pending.wdata);ctrl_code=ecc_encode({27'd0,pending.we,pending.mask});
     next.wait_count=voted.wait_count+1;
     if(ready)begin
      corrected_event=corrected_event|(!pending.we&&mr.corrected);
      if(bus_error||(!pending.we&&mr.uncorrectable))begin next.fatal=1;next.cause=32'h80000002;end
      else begin
       retire_valid=1;retire_result=pending.we?0:load_result;retire_rd=pending.rd_we?pending.rd:0;
       next.pc=pending.next_pc;next.state=ST_FETCH;next.wait_count=0;
      end
     end
    end
    default:begin next.fatal=1;next.cause=32'h80000001;end
   endcase
   if(sr.uncorrectable&&voted.scrub!=0)begin next.fatal=1;next.cause=32'h80000003;end
   if((voted.state==ST_FETCH||voted.state==ST_MEM)&&!ready&&voted.wait_count>=BUS_TIMEOUT-1)begin next.fatal=1;next.cause=32'h80000005;end
   if(voted.state==ST_FETCH&&voted.pc[1:0]!=0)begin next.fatal=1;next.cause=32'h80000001;end
  end
  if(external_fault&&!voted.fatal)begin next.fatal=1;next.cause=32'h80000006;end
  if(sr.corrected&&voted.scrub!=0)begin event_flags[0]=1;event_address={27'd0,voted.scrub};end
  if(voted.state==ST_EXEC&&(ar.corrected||br.corrected))begin event_flags[0]=1;event_address={27'd0,ar.corrected?voted.insn[19:15]:voted.insn[24:20]};end
  if((sr.uncorrectable&&voted.scrub!=0)||(voted.state==ST_EXEC&&(ar.uncorrectable||br.uncorrectable)))begin event_flags[1]=1;event_address={27'd0,sr.uncorrectable?voted.scrub:(ar.uncorrectable?voted.insn[19:15]:voted.insn[24:20])};end
  if(disagreement_event)begin event_flags[2]=1;event_address=voted.pc;end
  if(!voted.fatal&&next.fatal)begin
   case(next.cause)
    32'h80000004:event_flags[4]=1;
    32'h80000005:event_flags[5]=1;
    32'h80000001:event_flags[6]=1;
    32'h80000002:event_flags[3]=1;
    32'h80000006:event_flags[7]=1;
   endcase
   if(!event_flags[1])event_address=(voted.state==ST_MEM)?pending.addr:voted.pc;
  end
  if(next.fatal)begin next.state=ST_HALT;req=0;retire_valid=0;end
  fi_rf_base=rf[fi_index[4:0]];
  fi_tmr_base0=tmr0[fi_index[4:0]];fi_tmr_base1=tmr1[fi_index[4:0]];fi_tmr_base2=tmr2[fi_index[4:0]];
  if(sr.corrected&&voted.scrub==fi_index)begin fi_rf_base=sr.repaired;fi_tmr_base0=sr.data;fi_tmr_base1=sr.data;fi_tmr_base2=sr.data;end
  if(voted.state==ST_EXEC&&!next.fatal&&ar.corrected&&voted.insn[19:15]==fi_index)begin fi_rf_base=ar.repaired;fi_tmr_base0=ar.data;fi_tmr_base1=ar.data;fi_tmr_base2=ar.data;end
  if(voted.state==ST_EXEC&&!next.fatal&&br.corrected&&voted.insn[24:20]==fi_index)begin fi_rf_base=br.repaired;fi_tmr_base0=br.data;fi_tmr_base1=br.data;fi_tmr_base2=br.data;end
  if(retire_valid&&retire_rd==fi_index&&retire_rd!=0)begin fi_rf_base=ecc_encode(retire_result);fi_tmr_base0=retire_result;fi_tmr_base1=retire_result;fi_tmr_base2=retire_result;end
  if(fi_index==0)begin fi_rf_base=ecc_encode(0);fi_tmr_base0=32'd0;fi_tmr_base1=32'd0;fi_tmr_base2=32'd0;end
  halted=(voted.state==ST_HALT);fatal=voted.fatal;trap=voted.trap;trap_cause=voted.cause;trap_value=voted.tval;pc=voted.pc;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   c0<='0;c1<='0;c2<='0;
   c0.pc<=RESET_PC;c1.pc<=RESET_PC;c2.pc<=RESET_PC;
   c0.scrub<=1;c1.scrub<=1;c2.scrub<=1;
   for(i=0;i<32;i=i+1)write_reg(i,0);
  end else begin
   c0<=next;c1<=next;c2<=next;
   // Highest-priority architectural write wins over scrub/operand repair.
   if(sr.corrected&&voted.scrub!=0)repair_reg(voted.scrub,sr);
   if(voted.state==ST_EXEC&&!next.fatal)begin
    if(ar.corrected&&voted.insn[19:15]!=0)repair_reg(voted.insn[19:15],ar);
    if(br.corrected&&voted.insn[24:20]!=0)repair_reg(voted.insn[24:20],br);
   end
   if(retire_valid&&retire_rd!=0)write_reg(retire_rd,retire_result);
   write_reg(0,0);
   // Test-only stored-bit upset: injection wins over same-cycle repair/write.
   if(fi_ack)case(fi_target)
    1:if(!RF_TMR)rf[fi_index]<=fi_rf_base^fi_mask[38:0];
    2:if(RF_TMR)tmr0[fi_index]<=fi_tmr_base0^fi_mask[31:0];
    3:if(RF_TMR)tmr1[fi_index]<=fi_tmr_base1^fi_mask[31:0];
    4:if(RF_TMR)tmr2[fi_index]<=fi_tmr_base2^fi_mask[31:0];
    5:c0<=next^fi_mask[$bits(control_t)-1:0];
    6:c1<=next^fi_mask[$bits(control_t)-1:0];
    7:c2<=next^fi_mask[$bits(control_t)-1:0];
   endcase
  end
 end

`ifdef RISCV_FORMAL
 logic [63:0] formal_order;
 logic [31:0] formal_a,formal_b;
 wire formal_trap=(voted.state==ST_EXEC && e0.trap && !next.fatal);
 wire [6:0] formal_op=voted.insn[6:0];
 wire formal_rs1=(formal_op==7'h67||formal_op==7'h63||formal_op==7'h13||formal_op==7'h33||formal_op==7'h03||formal_op==7'h23);
 wire formal_rs2=(formal_op==7'h63||formal_op==7'h33||formal_op==7'h23);
 assign rvfi_valid=retire_valid||formal_trap;
 assign rvfi_order=formal_order;
 assign rvfi_insn=voted.insn;
 assign rvfi_trap=formal_trap;
 assign rvfi_halt=formal_trap;
 assign rvfi_intr=0;
 assign rvfi_mode=2'b11;
 assign rvfi_ixl=2'b01;
 assign rvfi_rs1_addr=formal_rs1?voted.insn[19:15]:0;
 assign rvfi_rs2_addr=formal_rs2?voted.insn[24:20]:0;
 assign rvfi_rs1_rdata=rvfi_rs1_addr!=0?((voted.state==ST_MEM)?formal_a:ar.data):0;
 assign rvfi_rs2_rdata=rvfi_rs2_addr!=0?((voted.state==ST_MEM)?formal_b:br.data):0;
 assign rvfi_rd_addr=formal_trap?0:retire_rd;
 assign rvfi_rd_wdata=rvfi_rd_addr!=0?retire_result:0;
 assign rvfi_pc_rdata=voted.pc;
 assign rvfi_pc_wdata=next.pc;
 assign rvfi_mem_addr=(voted.state==ST_MEM)?{pending.addr[31:2],2'b00}:0;
 assign rvfi_mem_wmask=(voted.state==ST_MEM&&pending.we)?pending.mask:0;
 assign rvfi_mem_rmask=(voted.state==ST_MEM&&!pending.we)?
  ((pending.load_kind==0||pending.load_kind==4)?(4'b0001<<pending.addr[1:0]):
  (pending.load_kind==1||pending.load_kind==5)?(4'b0011<<pending.addr[1:0]):4'b1111):0;
 assign rvfi_mem_rdata=mr.data;
 assign rvfi_mem_wdata=pending.wdata;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin formal_order<=0;formal_a<=0;formal_b<=0;end
  else begin
   if(rvfi_valid)formal_order<=formal_order+1;
   if(voted.state==ST_EXEC)begin formal_a<=ar.data;formal_b<=br.data;end
  end
 end
`endif
endmodule
