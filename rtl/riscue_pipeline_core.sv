// Default remains TMR. PARITY_REPLAY requires explicit experimental opt-in.
`ifndef RISCUE_PIPELINE_PROTECTION
`define RISCUE_PIPELINE_PROTECTION 0
`endif
`ifndef RISCUE_ALLOW_EXPERIMENTAL_PARITY
`define RISCUE_ALLOW_EXPERIMENTAL_PARITY 0
`endif
// Overlapping five-stage, in-order RV32IMC machine-mode core.
// Unified ECC-coded bus: req stays asserted through ready, then drops for
// one cycle. Stores issue only from MEM after older WB traps are resolved.
module riscue_pipeline_core #(
 parameter logic [31:0] RESET_PC=0,
 parameter integer BUS_TIMEOUT=1024,
 parameter integer PIPELINE_PROTECTION=`RISCUE_PIPELINE_PROTECTION,MAX_REPLAYS=3,
 parameter bit ALLOW_EXPERIMENTAL_PARITY=`RISCUE_ALLOW_EXPERIMENTAL_PARITY,
 parameter bit RF_TMR=0,FI_ENABLE=0,EARLY_JUMP=1,MONITOR_CONTROL=0,DEBUG_ENABLE=0
)(
 input logic clk,rst_n,external_irq,
 input logic debug_haltreq,debug_resumereq,
 output logic debug_halted,debug_resumeack,
 input logic debug_reg_valid,debug_reg_write,input logic [15:0] debug_regno,
 input logic [31:0] debug_wdata,output logic [31:0] debug_rdata,
 output logic debug_reg_ready,debug_reg_error,
 input logic halt_request,input logic [31:0] boot_pc,output wire quiescent,
 output logic req,output logic [38:0] addr_code,wdata_code,ctrl_code,
 input logic ready,bus_error,external_fault,input logic [38:0] rdata_code,
 output logic halted,fatal,trap,output logic [31:0] trap_cause,trap_value,pc,
 output logic corrected_event,disagreement_event,retire_valid,
 output logic [31:0] retire_pc,retire_insn,retire_result,output logic [4:0] retire_rd,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output logic fi_ack,
 output logic [7:0] event_flags,output logic [31:0] event_address,
 output logic [31:0] rvfi_pc_wdata,rvfi_rs1_rdata,rvfi_rs2_rdata,rvfi_mem_addr,rvfi_mem_rdata,rvfi_mem_wdata,
 output logic [4:0] rvfi_rs1_addr,rvfi_rs2_addr,
 output logic [3:0] rvfi_mem_rmask,rvfi_mem_wmask,
 output logic rvfi_trap,rvfi_intr,output logic [63:0] rvfi_order
);
 initial begin
  if(PIPELINE_PROTECTION<0||PIPELINE_PROTECTION>2)$fatal(1,"Invalid PIPELINE_PROTECTION");
  if(PIPELINE_PROTECTION==1&&!ALLOW_EXPERIMENTAL_PARITY)$fatal(1,"PARITY_REPLAY requires explicit experimental opt-in");
  if(PIPELINE_PROTECTION==2&&(RF_TMR||FI_ENABLE))$fatal(1,"PLAIN requires RF_TMR=0 and FI_ENABLE=0");
  if(MAX_REPLAYS<1)$fatal(1,"MAX_REPLAYS must be positive");
 end
 riscue_pipeline_engine #(.RESET_PC(RESET_PC),.BUS_TIMEOUT(BUS_TIMEOUT),
  .RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.EARLY_JUMP(EARLY_JUMP),
  .MONITOR_CONTROL(MONITOR_CONTROL),.DEBUG_ENABLE(DEBUG_ENABLE),
  .UNPROTECTED(PIPELINE_PROTECTION==2),.PARITY_REPLAY(PIPELINE_PROTECTION==1),.MAX_REPLAYS(MAX_REPLAYS)) impl(.*);
endmodule

// Overlapping five-stage, in-order RV32IMC machine-mode core.
// Unified ECC-coded bus: req stays asserted through ready, then drops for
// one cycle. Stores issue only from MEM after older WB traps are resolved.
module riscue_pipeline_engine #(
 parameter logic [31:0] RESET_PC=0,
 parameter integer BUS_TIMEOUT=1024,MAX_REPLAYS=3,parameter bit UNPROTECTED=0,PARITY_REPLAY=0,
 parameter bit RF_TMR=0,FI_ENABLE=0,EARLY_JUMP=1,MONITOR_CONTROL=0,DEBUG_ENABLE=0
)(
 input logic clk,rst_n,external_irq,
 input logic debug_haltreq,debug_resumereq,
 output logic debug_halted,debug_resumeack,
 input logic debug_reg_valid,debug_reg_write,input logic [15:0] debug_regno,
 input logic [31:0] debug_wdata,output logic [31:0] debug_rdata,
 output logic debug_reg_ready,debug_reg_error,
 input logic halt_request,input logic [31:0] boot_pc,output wire quiescent,
 output logic req,output logic [38:0] addr_code,wdata_code,ctrl_code,
 input logic ready,bus_error,external_fault,input logic [38:0] rdata_code,
 output logic halted,fatal,trap,output logic [31:0] trap_cause,trap_value,pc,
 output logic corrected_event,disagreement_event,retire_valid,
 output logic [31:0] retire_pc,retire_insn,retire_result,output logic [4:0] retire_rd,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output logic fi_ack,
 output logic [7:0] event_flags,output logic [31:0] event_address,
 output logic [31:0] rvfi_pc_wdata,rvfi_rs1_rdata,rvfi_rs2_rdata,rvfi_mem_addr,rvfi_mem_rdata,rvfi_mem_wdata,
 output logic [4:0] rvfi_rs1_addr,rvfi_rs2_addr,
 output logic [3:0] rvfi_mem_rmask,rvfi_mem_wmask,
 output logic rvfi_trap,rvfi_intr,output logic [63:0] rvfi_order
);
 import ft_pkg::*;
 import riscue_pipeline_pkg::*;
 function automatic [38:0] word_encode(input [31:0] v);
  word_encode=UNPROTECTED?{7'b0,v}:ecc_encode(v);
 endfunction
 function automatic ecc_result_t word_decode(input [38:0] v);
  ecc_result_t d;begin
   if(UNPROTECTED)begin d='0;d.data=v[31:0];d.repaired={7'b0,v[31:0]};end
   else d=ecc_decode(v);
   word_decode=d;
  end
 endfunction
 localparam integer STATE_BITS=$bits(state_t),WINDOWS=(STATE_BITS+511)/512;
 (* keep=UNPROTECTED?"false":"true",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) state_t c0,c1,c2;
 state_t s,n;
 // Only stage payloads use single-copy parity storage. Architectural and bus
 // state, including the committed retirement record, remain triplicated.
 function automatic state_t trusted(input state_t v);
  state_t t;begin t=v;t.f='0;t.d='0;t.x='0;t.m='0;t.w='0;trusted=t;end
 endfunction
 function automatic logic [4:0] stage_parity(input state_t v);
  stage_parity={^v.f,^v.d,^v.x,^v.m,^v.w};
 endfunction
 logic [4:0] payload_parity;
 logic payload_bad;
 localparam logic [4:0] REPLAY_RUN=5'b00000,REPLAY_DRAIN=5'b00111,
  REPLAY_RESTART=5'b11001,REPLAY_DEAD=5'b11110;
 typedef struct packed {logic [4:0] phase;logic [31:0] attempts;logic unsafe_memory;} replay_t;
 (* keep=UNPROTECTED?"false":"true",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) replay_t replay0,replay1,replay2;
 replay_t recovery,recovery_next;
 logic recovery_bad;

 state_t voted;

 wire monitor_stop=(MONITOR_CONTROL&&halt_request)||(DEBUG_ENABLE&&(debug_haltreq||s.debug_halted||(s.debug_step&&s.debug_step_issued)));
 assign quiescent=!s.half_valid&&!s.bus_active&&!s.f.valid&&!s.d.valid&&!s.x.valid&&!s.m.valid&&!s.w.valid;
 (* keep=UNPROTECTED?"false":"true",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) logic [38:0] rf[0:31];
 (* keep=UNPROTECTED?"false":"true",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) logic [31:0] tmr0[0:31],tmr1[0:31],tmr2[0:31];
 ecc_result_t ra,rb,scrubbed,response,debug_rf;
 exec_t e0,e1,executed;
 wire [31:0] d_insn=s.d.insn,d_pc=s.d.pc;
 wire [31:0] jump_target0,jump_target1;
 logic [31:0] xa,xb,csr_read,csr_operand,csr_new,load_data;
 logic csr_known,csr_ro,csr_write_intent,record_bad,rf_bad,execute_bad;
 logic [31:0] pending_irq;logic [31:0] irq_code;
 logic [15:0] fetch_half;
 logic [31:0] decompressed;
 logic compressed_illegal;
 logic md_start,md_cancel,md_ready0,md_ready1,md_done0,md_done1,md_dis0,md_dis1,md_fatal0,md_fatal1;
 logic [31:0] md_result0,md_result1;
 logic md_ack0,md_ack1,core_ack,rf_ack;
 logic [STATE_BITS-1:0] injection;
 logic x_mop,x_block,m_block,flush,serial_pending,load_hazard,id_jump_redirect;
 logic write_rf;logic [4:0] write_rd;logic [31:0] write_value;
 wire [31:0] x_insn=s.x.insn,x_pc=s.x.pc;wire [2:0] x_bytes=s.x.bytes;
 logic [38:0] fi_rf_base;
 logic [3:0] store_mask;logic [31:0] store_data;
 integer j,k;
 function automatic logic uses1(input [31:0] insn);
  case(insn[6:0])
   7'h33,7'h13,7'h03,7'h23,7'h63,7'h67:uses1=1;
   7'h73:uses1=insn[14:12]!=0&&!insn[14];
   default:uses1=0;
  endcase
 endfunction
 function automatic logic uses2(input [31:0] insn);
  uses2=insn[6:0]==7'h33||insn[6:0]==7'h23||insn[6:0]==7'h63;
 endfunction
 function automatic logic serial(input [31:0] insn);
  serial=insn[6:0]==7'h73||(insn[6:0]==7'h0f&&insn[14:12]==1);
 endfunction
 function automatic logic clint(input [31:0] a);
  clint=(a&32'hfffffffc)==32'h02000000 || (a&32'hfffffff8)==32'h02004000 || (a&32'hfffffff8)==32'h0200bff8;
 endfunction
 function automatic [31:0] extend_load(input [31:0] data,input [1:0] offset,input [2:0] kind);
  logic [31:0] v;
  begin v=data>>(offset*8);
   case(kind)
    0:extend_load={{24{v[7]}},v[7:0]};1:extend_load={{16{v[15]}},v[15:0]};
    4:extend_load={24'b0,v[7:0]};5:extend_load={16'b0,v[15:0]};default:extend_load=v;
   endcase
  end
 endfunction
 (* keep_hierarchy=UNPROTECTED?"no":"yes",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) riscue_jump_target jump0(.insn(d_insn),.pc(d_pc),.target(jump_target0));
 generate if(!UNPROTECTED)begin: protected_jump
 (* keep_hierarchy=UNPROTECTED?"no":"yes",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) riscue_jump_target jump1(.insn(d_insn),.pc(d_pc),.target(jump_target1));
 end else begin assign jump_target1=jump_target0;end endgenerate
 riscue_rvc decompress(.c(fetch_half),.insn(decompressed),.illegal(compressed_illegal));
 (* keep_hierarchy=UNPROTECTED?"no":"yes",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) riscue_execute #(.COMPRESSED(1),.MULTICYCLE_M(1)) lane0(
  .instruction_bytes(x_bytes),.insn(x_insn),.pc(x_pc),.a(xa),.b(xb),.out(e0));
 generate if(!UNPROTECTED)begin: protected_lane1
 (* keep_hierarchy=UNPROTECTED?"no":"yes",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) riscue_execute #(.COMPRESSED(1),.MULTICYCLE_M(1)) lane1(
  .instruction_bytes(x_bytes),.insn(x_insn),.pc(x_pc),.a(xa),.b(xb),.out(e1));
 end else begin assign e1=e0; end endgenerate
 (* keep_hierarchy=UNPROTECTED?"no":"yes",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) riscue_muldiv #(.UNPROTECTED(UNPROTECTED),.FI_ENABLE(FI_ENABLE)) arithmetic0(
  .clk(clk),.rst_n(rst_n),.start(md_start),.cancel(md_cancel),.op(s.x.insn[14:12]),.lhs(xa),.rhs(xb),
  .ready(md_ready0),.done(md_done0),.disagreement(md_dis0),.fatal(md_fatal0),.result(md_result0),
  .fi_valid(fi_valid&&fi_target==15&&fi_index[31:8]==0&&fi_index[7:2]==0),.fi_replica(fi_index[1:0]),.fi_mask(fi_mask),.fi_ack(md_ack0));
 generate if(!UNPROTECTED)begin: protected_arithmetic1
 (* keep_hierarchy=UNPROTECTED?"no":"yes",DONT_TOUCH=UNPROTECTED?"FALSE":"TRUE" *) riscue_muldiv #(.UNPROTECTED(UNPROTECTED),.FI_ENABLE(FI_ENABLE)) arithmetic1(
  .clk(clk),.rst_n(rst_n),.start(md_start),.cancel(md_cancel),.op(s.x.insn[14:12]),.lhs(xa),.rhs(xb),
  .ready(md_ready1),.done(md_done1),.disagreement(md_dis1),.fatal(md_fatal1),.result(md_result1),
  .fi_valid(fi_valid&&fi_target==15&&fi_index[31:8]==1&&fi_index[7:2]==0),.fi_replica(fi_index[1:0]),.fi_mask(fi_mask),.fi_ack(md_ack1));
 end else begin assign md_ready1=md_ready0;assign md_done1=md_done0;assign md_dis1=0;assign md_fatal1=0;assign md_result1=md_result0;assign md_ack1=0; end endgenerate
 wire forward_m=s.m.valid&&!s.m.trap&&s.m.e.rd_we&&s.m.e.rd!=0&&!s.m.e.mem;
 wire forward_w=s.w.valid&&!s.w.trap&&s.w.e.rd_we&&s.w.e.rd!=0;
 assign xa=s.x.rs1==0?32'b0:forward_m&&s.x.rs1==s.m.e.rd?s.m.e.result:forward_w&&s.x.rs1==s.w.e.rd?s.w.e.result:s.x.a;
 assign xb=s.x.rs2==0?32'b0:forward_m&&s.x.rs2==s.m.e.rd?s.m.e.result:forward_w&&s.x.rs2==s.w.e.rd?s.w.e.result:s.x.b;
 always_comb begin
  recovery=(replay0&replay1)|(replay0&replay2)|(replay1&replay2);
  recovery_next=recovery;
  recovery_bad=((replay0!=replay1)&&(replay0!=replay2)&&(replay1!=replay2))||
   !(recovery.phase==REPLAY_RUN||recovery.phase==REPLAY_DRAIN||recovery.phase==REPLAY_RESTART||recovery.phase==REPLAY_DEAD);
  voted=(c0&c1)|(c0&c2)|(c1&c2);
  s=UNPROTECTED?c0:voted;
  payload_bad=PARITY_REPLAY&&(stage_parity(c0)!=payload_parity);
  if(PARITY_REPLAY)begin
   s.f=c0.f;s.d=c0.d;s.x=c0.x;s.m=c0.m;s.w=c0.w;
   // Contain corrupt control before operand addressing or commit decisions.
   if(payload_bad)begin s.f='0;s.d='0;s.x='0;s.m='0;s.w='0;end
  end
  if(UNPROTECTED)begin recovery='0;recovery_next='0;recovery_bad=0;end
  n=s;
  store_mask=s.m.e.mask;store_data=s.m.e.wdata;
  record_bad=PARITY_REPLAY?((trusted(c0)!=c1)&&(trusted(c0)!=c2)&&(c1!=c2)):((c0!=c1)&&(c0!=c2)&&(c1!=c2));
  if(UNPROTECTED)record_bad=0;
  ra=word_decode(rf[s.d.insn[19:15]]);rb=word_decode(rf[s.d.insn[24:20]]);scrubbed=word_decode(rf[s.scrub]);response=word_decode(rdata_code);
  rf_bad=!RF_TMR&&((s.d.valid&&uses1(s.d.insn)&&ra.uncorrectable)||(s.d.valid&&uses2(s.d.insn)&&rb.uncorrectable)||scrubbed.uncorrectable);
  if(RF_TMR)begin
   ra.data=(tmr0[s.d.insn[19:15]]&tmr1[s.d.insn[19:15]])|(tmr0[s.d.insn[19:15]]&tmr2[s.d.insn[19:15]])|(tmr1[s.d.insn[19:15]]&tmr2[s.d.insn[19:15]]);
   rb.data=(tmr0[s.d.insn[24:20]]&tmr1[s.d.insn[24:20]])|(tmr0[s.d.insn[24:20]]&tmr2[s.d.insn[24:20]])|(tmr1[s.d.insn[24:20]]&tmr2[s.d.insn[24:20]]);
  end
  load_hazard=s.m.valid&&s.m.e.mem&&!s.m.e.we&&s.m.e.rd!=0&&((uses1(s.x.insn)&&s.x.rs1==s.m.e.rd)||(uses2(s.x.insn)&&s.x.rs2==s.m.e.rd));
  csr_known=1;csr_ro=0;csr_read=0;
  case(s.x.insn[31:20])
   12'h300:csr_read=32'h1800|(s.mie_global?32'h8:0)|(s.mpie?32'h80:0);
   12'h301:begin csr_read=32'h40001104;end
   12'h304:csr_read=s.mie;
   12'h305:csr_read=s.mtvec;
   12'h340:csr_read=s.mscratch;
   12'h341:csr_read=s.mepc;
   12'h342:csr_read=s.mcause;
   12'h343:csr_read=s.mtval;
   12'h344:csr_read=(s.msip?32'h8:0)|(s.mtime>=s.mtimecmp?32'h80:0)|(s.irq_sync?32'h800:0);
   12'hb00:csr_read=s.mcycle[31:0];12'hb80:csr_read=s.mcycle[63:32];
   12'hb02:csr_read=s.minstret[31:0];12'hb82:csr_read=s.minstret[63:32];
   12'hc00:begin csr_read=s.mcycle[31:0];csr_ro=1;end
   12'hc80:begin csr_read=s.mcycle[63:32];csr_ro=1;end
   12'hc02:begin csr_read=s.minstret[31:0];csr_ro=1;end
   12'hc82:begin csr_read=s.minstret[63:32];csr_ro=1;end
   12'hc01:begin csr_read=s.mtime[31:0];csr_ro=1;end
   12'hc81:begin csr_read=s.mtime[63:32];csr_ro=1;end
   12'hf11,12'hf12,12'hf13,12'hf14:begin csr_read=0;csr_ro=1;end
   default:csr_known=0;
  endcase
  csr_operand=s.x.insn[14]?{27'b0,s.x.insn[19:15]}:xa;
  csr_write_intent=s.x.insn[13:12]==1||(s.x.insn[19:15]!=0);
  case(s.x.insn[13:12])
   1:csr_new=csr_operand;2:csr_new=csr_read|csr_operand;3:csr_new=csr_read&~csr_operand;default:csr_new=csr_read;
  endcase
  executed=e0;
  if(s.x.insn[6:0]==7'h73)begin
   if(s.x.insn[14:12]!=0&&s.x.insn[13:12]!=0)begin
    executed='0;executed.rd=s.x.insn[11:7];executed.rd_we=1;executed.result=csr_read;executed.next_pc=s.x.pc+s.x.bytes;
    if(!csr_known||(csr_ro&&csr_write_intent))begin executed.trap=1;executed.cause=2;executed.tval=s.x.raw;end
   end else if(s.x.insn==32'h30200073||s.x.insn==32'h10500073)begin
    executed='0;executed.next_pc=s.x.insn==32'h30200073 ?s.mepc:s.x.pc+s.x.bytes;
   end
  end
  if(s.x.trap)begin executed='0;executed.trap=1;executed.cause=s.x.cause;executed.tval=s.x.tval;end
  if(executed.trap)begin executed.rd_we=0;executed.mem=0;executed.we=0;if(executed.cause==2)executed.tval=s.x.raw;end
  x_mop=s.x.insn[6:0]==7'h33&&s.x.insn[31:25]==1&&!s.x.trap;
  if(x_mop)executed.result=s.x_result;
  execute_bad=(EARLY_JUMP&&s.d.valid&&!s.d.trap&&s.d.insn[6:0]==7'h6f&&jump_target0!=jump_target1)||(s.x.valid&&e0!=e1)||md_done0!=md_done1||md_ready0!=md_ready1||(md_done0&&md_result0!=md_result1)||md_fatal0||md_fatal1;
  corrected_event=!RF_TMR&&((s.d.valid&&(ra.corrected||rb.corrected))||scrubbed.corrected)||(s.bus_active&&ready&&response.corrected);
  disagreement_event=(PARITY_REPLAY?((trusted(c0)!=c1)||(trusted(c0)!=c2)||payload_bad||(replay0!=replay1)||(replay0!=replay2)):((c0!=c1)||(c0!=c2)))||md_dis0||md_dis1;
  if(UNPROTECTED)begin corrected_event=0;disagreement_event=0;execute_bad=md_fatal0;end
  if(RF_TMR)for(j=0;j<32;j=j+1)begin
   if(tmr0[j]!=tmr1[j]||tmr0[j]!=tmr2[j])disagreement_event=1;
   if(tmr0[j]!=tmr1[j]&&tmr0[j]!=tmr2[j]&&tmr1[j]!=tmr2[j])rf_bad=1;
  end
  fatal=(PARITY_REPLAY&&(recovery_bad||recovery.phase==REPLAY_DEAD||(payload_bad&&(recovery.unsafe_memory||recovery.attempts>=MAX_REPLAYS))))||s.fatal||record_bad||rf_bad||execute_bad||external_fault||(s.bus_active&&ready&&response.uncorrectable);
  halted=fatal;trap=s.trap_pulse;trap_cause=s.mcause;trap_value=s.mtval;pc=s.arch_pc;
  req=rst_n&&s.bus_active&&!fatal&&!(s.w.valid&&s.w.trap&&s.bus_data);
  addr_code=word_encode(s.bus_addr);wdata_code=word_encode(s.bus_wdata);ctrl_code=word_encode(s.bus_ctrl);
  retire_valid=rst_n&&s.retire;retire_pc=s.retired.pc;retire_insn=s.retired.raw;retire_rd=s.retired.e.rd_we?s.retired.e.rd:0;
  retire_result=retire_rd==0?0:s.retired.e.result;
  rvfi_pc_wdata=s.retired.e.next_pc;rvfi_rs1_addr=s.retired.rs1;rvfi_rs2_addr=s.retired.rs2;
  rvfi_rs1_rdata=s.retired.a;rvfi_rs2_rdata=s.retired.b;
  rvfi_mem_addr=s.retired.e.addr&32'hfffffffc;rvfi_mem_rdata=s.retired.mem_data;rvfi_mem_wdata=s.retired.e.wdata;
  rvfi_mem_rmask=s.retired.e.mem&&!s.retired.e.we?(s.retired.e.load_kind==0||s.retired.e.load_kind==4?4'b0001:s.retired.e.load_kind==1||s.retired.e.load_kind==5?4'b0011:4'b1111)<<s.retired.e.addr[1:0]:0;
  rvfi_mem_wmask=s.retired.e.mem&&s.retired.e.we?s.retired.e.mask:0;
  rvfi_trap=s.retire_trap;rvfi_intr=s.retire_intr;rvfi_order=s.order-1;
  fetch_half=s.bus_pc[1]?response.data[31:16]:response.data[15:0];
  event_flags=0;event_address=s.arch_pc;
  if(corrected_event)event_flags[0]=1;
  if(rf_bad||(s.bus_active&&ready&&response.uncorrectable))event_flags[1]=1;
  if(disagreement_event)event_flags[2]=1;
  if(s.bus_active&&ready&&bus_error)begin if(external_fault)event_flags[3]=1;event_address=s.bus_pc;end
  if(execute_bad)event_flags[4]=1;
  if(record_bad||(PARITY_REPLAY&&recovery_bad))event_flags[6]=1;
  if(external_fault)event_flags[7]=1;
  n.retire=0;n.retire_trap=0;n.retire_intr=0;n.trap_pulse=0;
  n.mcycle=s.mcycle+1;n.mtime=s.mtime+1;n.irq_meta=external_irq;n.irq_sync=s.irq_meta;
  n.scrub=UNPROTECTED?0:s.scrub+1'b1;n.bus_cooldown=0;
  id_jump_redirect=0;write_rf=0;write_rd=0;write_value=0;flush=0;m_block=0;x_block=0;load_data=0;
  md_start=0;md_cancel=0;
  serial_pending=(s.x.valid&&s.x.serial)||(s.m.valid&&s.m.serial)||(s.w.valid&&s.w.serial);
  if(!fatal&&!(DEBUG_ENABLE&&s.debug_halted))begin
   // WB is the only architectural register/CSR commit point.
   if(s.w.valid)begin
    n.w.valid=0;n.retire=1;n.retired=s.w;n.order=s.order+1;n.retire_intr=s.interrupt_next;n.interrupt_next=0;
    if(DEBUG_ENABLE&&s.w.trap&&s.w.cause==3&&s.debug_ebreakm)begin
     n.debug_halted=1;n.debug_cause=1;n.arch_pc=s.w.pc;n.fetch_pc=s.w.pc;
     n.retire=0;n.order=s.order;n.interrupt_next=s.interrupt_next;flush=1;
    end else if(s.w.trap)begin
     n.mepc=s.w.pc&32'hfffffffe;n.mcause=s.w.cause;n.mtval=s.w.tval;
     n.mpie=s.mie_global;n.mie_global=0;n.trap_pulse=1;n.retire_trap=1;
     n.fetch_pc=s.mtvec;n.arch_pc=s.mtvec;n.retired.e.next_pc=s.mtvec;flush=1;
    end else begin
     n.minstret=s.minstret+1;n.arch_pc=s.w.e.next_pc;
     write_rf=s.w.e.rd_we&&s.w.e.rd!=0;write_rd=s.w.e.rd;write_value=s.w.e.result;
     if(s.w.csr&&s.w.csr_write)case(s.w.csr_addr)
      12'h300:begin n.mie_global=s.w.csr_value[3];n.mpie=s.w.csr_value[7];end
      12'h304:n.mie=s.w.csr_value&32'h888;
      12'h305:n.mtvec=s.w.csr_value&32'hfffffffc;
      12'h340:n.mscratch=s.w.csr_value;
      12'h341:n.mepc=s.w.csr_value&32'hfffffffe;
      12'h342:n.mcause=s.w.csr_value;12'h343:n.mtval=s.w.csr_value;
      12'hb00:n.mcycle[31:0]=s.w.csr_value;12'hb80:n.mcycle[63:32]=s.w.csr_value;
      12'hb02:n.minstret[31:0]=s.w.csr_value;12'hb82:n.minstret[63:32]=s.w.csr_value;
      default:begin end // mip is read-only hardware pending, writes ignored
     endcase
     if(s.w.mret)begin n.mie_global=s.mpie;n.mpie=1;n.fetch_pc=s.mepc;flush=1;end
     if(s.w.fencei)begin n.fetch_pc=s.w.e.next_pc;flush=1;end
    end
   end
   if(DEBUG_ENABLE&&s.debug_step&&s.w.valid&&!n.debug_halted)begin
    n.debug_halted=1;n.debug_cause=4;n.fetch_pc=n.arch_pc;flush=1;
   end
   if(!flush)begin
    // MEM progresses independently of stalled EX and instruction fetch.
    if(s.m.valid&&!n.w.valid)begin
     if(!s.m.e.mem||s.m.trap)begin n.w=s.m;n.m.valid=0;end
     else if(clint(s.m.e.addr)&&!s.bus_active)begin
      case(s.m.e.addr&32'hfffffffc)
       32'h02000000:load_data={31'b0,s.msip};
       32'h02004000:load_data=s.mtimecmp[31:0];32'h02004004:load_data=s.mtimecmp[63:32];
       32'h0200bff8:load_data=s.mtime[31:0];32'h0200bffc:load_data=s.mtime[63:32];
       default:load_data=0;
      endcase
      if(s.m.e.we)for(k=0;k<4;k=k+1)if(store_mask[k])case(s.m.e.addr&32'hfffffffc)
       32'h02000000:if(k==0)n.msip=s.m.e.wdata[0];
       32'h02004000:n.mtimecmp=(n.mtimecmp&~(64'hff<<(k*8)))|({56'b0,store_data[k*8+:8]}<<(k*8));
       32'h02004004:n.mtimecmp=(n.mtimecmp&~(64'hff<<(32+k*8)))|({56'b0,store_data[k*8+:8]}<<(32+k*8));
       32'h0200bff8:n.mtime=(n.mtime&~(64'hff<<(k*8)))|({56'b0,store_data[k*8+:8]}<<(k*8));
       32'h0200bffc:n.mtime=(n.mtime&~(64'hff<<(32+k*8)))|({56'b0,store_data[k*8+:8]}<<(32+k*8));
       default:begin end
      endcase
      n.w=s.m;n.w.mem_data=load_data;n.w.e.result=extend_load(load_data,s.m.e.addr[1:0],s.m.e.load_kind);n.m.valid=0;
     end
    end
    if(s.bus_active)begin
     if(ready)begin
      n.bus_active=0;n.bus_wait=0;n.bus_cooldown=1;
      if(s.bus_data)begin
       n.w=s.m;n.m.valid=0;n.w.mem_data=response.data;
       n.w.e.result=extend_load(response.data,s.m.e.addr[1:0],s.m.e.load_kind);
       if(bus_error)begin n.w.trap=1;n.w.cause=s.m.e.we?7:5;n.w.tval=s.m.e.addr;n.w.e.rd_we=0;n.w.e.mem=0;end
      end else if(!s.bus_kill&&!s.irq_drain)begin
       n.f='0;n.f.valid=1;n.f.pc=s.bus_pc;n.f.bytes=4;
       if(bus_error)begin n.f.trap=1;n.f.cause=1;n.f.tval=s.bus_half?s.bus_pc+2:s.bus_pc;n.f.insn=32'h13;end
       else if(s.bus_half)begin n.f.raw={response.data[15:0],s.half_word[15:0]};n.f.insn=n.f.raw;n.half_valid=0;end
       else if(fetch_half[1:0]!=3)begin
        n.f.bytes=2;n.f.raw={16'b0,fetch_half};n.f.insn=decompressed;
        n.f.trap=compressed_illegal;n.f.cause=2;n.f.tval=n.f.raw;
       end else if(s.bus_pc[1])begin n.half_word={16'b0,fetch_half};n.half_valid=1;n.f.valid=0;end
       else begin n.f.raw=response.data;n.f.insn=response.data;end
       if(n.f.valid)begin n.fetch_pc=s.bus_pc+n.f.bytes;n.f.serial=serial(n.f.insn)||n.f.trap;end
      end
     end else if(s.bus_wait>=BUS_TIMEOUT-1)begin n.fatal=1;event_flags[5]=1;end
     else n.bus_wait=s.bus_wait+1;
    end
    if(s.x.valid)begin
     n.x.a=xa;n.x.b=xb;
     if(x_mop&&!s.x_started&&!load_hazard&&md_ready0&&md_ready1)begin md_start=1;n.x_started=1;end
     if(s.x_started&&md_done0)begin n.x_done=1;n.x_result=md_result0;end
     x_block=load_hazard||(x_mop&&!s.x_done);
     if(!n.m.valid&&!x_block)begin
      n.m=s.x;n.m.e=executed;n.m.a=xa;n.m.b=xb;n.m.trap=executed.trap;n.m.cause=executed.cause;n.m.tval=executed.tval;
      n.m.csr=s.x.insn[6:0]==7'h73&&s.x.insn[14:12]!=0;
      n.m.csr_addr=s.x.insn[31:20];n.m.csr_value=csr_new;n.m.csr_write=csr_write_intent;
      n.m.mret=s.x.insn==32'h30200073;n.m.fencei=s.x.insn[6:0]==7'h0f&&s.x.insn[14:12]==1;
      n.x.valid=0;n.x_started=0;n.x_done=0;
      if(!executed.trap&&executed.next_pc!=s.x.pc+s.x.bytes&&!n.m.mret&&!(EARLY_JUMP&&s.x.insn[6:0]==7'h6f))begin
       n.fetch_pc=executed.next_pc;n.f.valid=0;n.d.valid=0;n.half_valid=0;
       if(n.bus_active&&!n.bus_data)n.bus_kill=1;
      end
     end
    end
    // Drain accepted instructions before taking an interrupt; fetch is squashed.
    pending_irq=n.mie&((n.msip?32'h8:0)|(n.mtime>=n.mtimecmp?32'h80:0)|(n.irq_sync?32'h800:0));
    irq_code=pending_irq[11]?32'h8000000b:pending_irq[3]?32'h80000003:32'h80000007;
    if(!(DEBUG_ENABLE&&(s.debug_step||debug_haltreq))&&!s.irq_drain&&n.mie_global&&pending_irq!=0&&!serial_pending)begin
     n.irq_drain=1;n.irq_cause=irq_code;n.f.valid=0;n.d.valid=0;n.half_valid=0;
     if(n.bus_active&&!n.bus_data)n.bus_kill=1;
    end
    if(n.irq_drain&&!n.x.valid&&!n.m.valid&&!n.w.valid)begin
     n.mepc=n.arch_pc;n.mcause=n.irq_cause;n.mtval=0;n.mpie=n.mie_global;n.mie_global=0;
     n.fetch_pc=n.mtvec;n.arch_pc=n.mtvec;n.irq_drain=0;n.trap_pulse=1;n.interrupt_next=1;flush=1;
    end
    if(!n.irq_drain&&!flush)begin
     if(s.d.valid&&n.d.valid&&!n.x.valid&&!serial_pending&&!(n.m.valid&&n.m.trap)&&!(n.w.valid&&n.w.trap)&&(!s.d.serial||(!s.x.valid&&!s.m.valid&&!s.w.valid)))begin
      n.x=s.d;n.d.valid=0;n.x.rs1=uses1(s.d.insn)?s.d.insn[19:15]:0;n.x.rs2=uses2(s.d.insn)?s.d.insn[24:20]:0;
      n.x.a=n.x.rs1==0?0:ra.data;n.x.b=n.x.rs2==0?0:rb.data;
      if(write_rf&&write_rd==n.x.rs1)n.x.a=write_value;
      if(write_rf&&write_rd==n.x.rs2)n.x.b=write_value;
      // Redirect only when ID is accepted into EX. Earlier EX redirects
      // invalidate n.d above; WB traps/interrupt draining block this path.
      // EX still computes the link and target for retirement, without a
      // second JAL flush that would discard instructions at the target.
      if(EARLY_JUMP&&!s.d.trap&&s.d.insn[6:0]==7'h6f&&jump_target0!=s.d.pc+s.d.bytes)begin
       id_jump_redirect=1;n.fetch_pc=jump_target0;n.f.valid=0;n.half_valid=0;
       if(n.bus_active&&!n.bus_data)n.bus_kill=1;
      end
     end
     if(s.f.valid&&n.f.valid&&!n.d.valid)begin n.d=s.f;n.f.valid=0;end
    end
    // Unified bus arbitration gives MEM priority, with a required idle bubble.
    if(!s.bus_active&&!s.bus_cooldown&&!n.bus_active)begin
     if(n.m.valid&&n.m.e.mem&&!n.m.trap&&!(n.w.valid&&n.w.trap)&&!clint(n.m.e.addr))begin
      n.bus_active=1;n.bus_data=1;n.bus_kill=0;n.bus_pc=n.m.e.addr;
      n.bus_addr=n.m.e.addr&32'hfffffffc;n.bus_wdata=n.m.e.wdata;n.bus_ctrl=n.m.e.we?(32'h10|32'(n.m.e.mask)):32'b0;n.bus_wait=0;
     end else if((!monitor_stop||n.half_valid)&&!n.f.valid&&!n.irq_drain&&!flush&&!serial_pending)begin
      if(n.fetch_pc[0])begin n.f='0;n.f.valid=1;n.f.pc=n.fetch_pc;n.f.trap=1;n.f.serial=1;n.f.cause=0;n.f.tval=n.fetch_pc;n.f.bytes=2;end
      else begin
       n.bus_active=1;n.bus_data=0;n.bus_kill=0;n.bus_half=n.half_valid;
       if(DEBUG_ENABLE&&s.debug_step)n.debug_step_issued=1;n.bus_pc=n.fetch_pc;
       n.bus_addr=n.half_valid?((n.fetch_pc&32'hfffffffc)+4):(n.fetch_pc&32'hfffffffc);n.bus_ctrl=0;n.bus_wdata=0;n.bus_wait=0;
      end
     end
    end
   end
   if(flush)begin
    n.f.valid=0;n.d.valid=0;n.x.valid=0;n.m.valid=0;n.w.valid=0;n.half_valid=0;n.x_started=0;n.x_done=0;
    if(n.bus_active&&!n.bus_data)begin
     n.bus_kill=1;
     if(ready)begin n.bus_active=0;n.bus_cooldown=1;n.bus_wait=0;end
    end
    md_cancel=1;
   end
  end else if(fatal)begin n.fatal=1;n.bus_active=0;n.retire=0;md_cancel=1;end
  debug_halted=DEBUG_ENABLE&&s.debug_halted&&!fatal;
  debug_resumeack=DEBUG_ENABLE&&s.debug_halted&&debug_resumereq&&!debug_haltreq&&!fatal;
  debug_reg_ready=DEBUG_ENABLE&&debug_reg_valid;
  debug_reg_error=!debug_halted;
  debug_rdata=0;debug_rf=word_decode(rf[debug_regno[4:0]]);
  if(DEBUG_ENABLE)begin
   if(s.debug_halted)begin
    n.mcycle=s.mcycle;n.mtime=s.mtime;
    // A flushed speculative fetch still completes before SBA takes ownership.
    if(s.bus_active&&!s.bus_data&&ready)begin n.bus_active=0;n.bus_cooldown=1;n.bus_wait=0;end
   end
   if(debug_haltreq&&!n.bus_active&&!n.half_valid&&!n.f.valid&&!n.d.valid&&!n.x.valid&&!n.m.valid&&!n.w.valid&&!fatal&&!s.debug_halted)begin
    n.debug_halted=1;n.debug_cause=3;n.fetch_pc=n.arch_pc;
   end
   if(debug_resumeack)begin
    n.debug_halted=0;n.debug_step_issued=0;n.fetch_pc=s.arch_pc;n.half_valid=0;
   end
   if(debug_regno>=16'h1000&&debug_regno<=16'h101f)begin
    debug_rdata=debug_regno[4:0]==0?0:RF_TMR?
     ((tmr0[debug_regno[4:0]]&tmr1[debug_regno[4:0]])|(tmr0[debug_regno[4:0]]&tmr2[debug_regno[4:0]])|(tmr1[debug_regno[4:0]]&tmr2[debug_regno[4:0]])):debug_rf.data;
    if(!RF_TMR&&debug_rf.uncorrectable)debug_reg_error=1;
    if(debug_reg_valid&&debug_reg_write&&!debug_reg_error&&debug_regno[4:0]!=0)begin
     write_rf=1;write_rd=debug_regno[4:0];write_value=debug_wdata;
    end
   end else case(debug_regno)
    16'h7b0:begin
     debug_rdata=32'h40000603|({29'b0,s.debug_cause}<<6)|(s.debug_step?32'h4:0)|(s.debug_ebreakm?32'h8000:0);
     if(debug_reg_valid&&debug_reg_write&&!debug_reg_error)begin n.debug_step=debug_wdata[2];n.debug_ebreakm=debug_wdata[15];end
    end
    16'h7b1:begin debug_rdata=s.arch_pc;if(debug_reg_valid&&debug_reg_write&&!debug_reg_error)begin n.arch_pc=debug_wdata&32'hfffffffe;n.fetch_pc=n.arch_pc;end end
    16'h301:debug_rdata=32'h40001104;
    16'hf11,16'hf12,16'hf13,16'hf14:debug_rdata=0;
    16'h300:debug_rdata=32'h1800|(s.mie_global?32'h8:0)|(s.mpie?32'h80:0);
    16'h304:debug_rdata=s.mie;16'h305:debug_rdata=s.mtvec;
    16'h340:debug_rdata=s.mscratch;16'h341:debug_rdata=s.mepc;16'h342:debug_rdata=s.mcause;16'h343:debug_rdata=s.mtval;
    16'h344:debug_rdata=(s.msip?32'h8:0)|(s.mtime>=s.mtimecmp?32'h80:0)|(s.irq_sync?32'h800:0);
    16'hb00,16'hc00:debug_rdata=s.mcycle[31:0];16'hb80,16'hc80:debug_rdata=s.mcycle[63:32];
    16'hb02,16'hc02:debug_rdata=s.minstret[31:0];16'hb82,16'hc82:debug_rdata=s.minstret[63:32];
    16'hc01:debug_rdata=s.mtime[31:0];16'hc81:debug_rdata=s.mtime[63:32];
    default:debug_reg_error=1;
   endcase
   if(debug_reg_valid&&debug_reg_write&&!debug_reg_error&&debug_regno<16'h1000&&debug_regno!=16'h7b0&&debug_regno!=16'h7b1)case(debug_regno)
    16'h300:begin n.mie_global=debug_wdata[3];n.mpie=debug_wdata[7];end
    16'h304:n.mie=debug_wdata&32'h888;16'h305:n.mtvec=debug_wdata&32'hfffffffc;
    16'h340:n.mscratch=debug_wdata;16'h341:n.mepc=debug_wdata&32'hfffffffe;
    16'h342:n.mcause=debug_wdata;16'h343:n.mtval=debug_wdata;
    16'hb00:n.mcycle[31:0]=debug_wdata;16'hb80:n.mcycle[63:32]=debug_wdata;
    16'hb02:n.minstret[31:0]=debug_wdata;16'hb82:n.minstret[63:32]=debug_wdata;
    default:debug_reg_error=1;
   endcase
  end
  pending_irq=0;irq_code=0; // temporaries have no architectural storage
  if(PARITY_REPLAY)begin
   if(payload_bad||recovery.phase!=REPLAY_RUN||recovery_bad)begin
    // Roll back only uncommitted stages. Keep the trusted architectural state
    // and drain a previously issued instruction read without using its data.
    n=s;n.f='0;n.d='0;n.x='0;n.m='0;n.w='0;
    n.half_valid=0;n.x_started=0;n.x_done=0;n.fetch_pc=s.arch_pc;
    n.retire=0;n.retire_trap=0;n.retire_intr=0;n.trap_pulse=0;
    n.mcycle=s.mcycle+1;n.mtime=s.mtime+1;
    write_rf=0;md_start=0;md_cancel=1;id_jump_redirect=0;
    debug_reg_ready=0;debug_resumeack=0;
    if(fatal)begin
     n.fatal=1;n.bus_active=0;recovery_next.phase=REPLAY_DEAD;
    end else if(payload_bad&&recovery.phase==REPLAY_RUN)begin
     recovery_next.attempts=recovery.attempts+1;
     recovery_next.phase=s.bus_active?REPLAY_DRAIN:REPLAY_RESTART;
     n.bus_kill=s.bus_active;
     // A response accepted on this same edge is drained exactly once.
     if(s.bus_active&&ready)begin n.bus_active=0;n.bus_cooldown=1;recovery_next.phase=REPLAY_RESTART;end
    end else if(recovery.phase==REPLAY_DRAIN)begin
     n.bus_kill=1;
     if(ready||!s.bus_active)begin n.bus_active=0;n.bus_cooldown=1;n.bus_wait=0;recovery_next.phase=REPLAY_RESTART;end
     else if(s.bus_wait>=BUS_TIMEOUT-1)begin n.fatal=1;n.bus_active=0;event_flags[5]=1;recovery_next.phase=REPLAY_DEAD;end
     else n.bus_wait=s.bus_wait+1;
    end else if(recovery.phase==REPLAY_RESTART)begin
     n.bus_active=0;n.bus_cooldown=1;recovery_next.phase=REPLAY_RUN;
    end
    if(payload_bad)event_flags[6]=1;
   end
   // This flag is independently triplicated; corrupt stage bits cannot clear
   // the evidence that a memory transaction may already have side effects.
   recovery_next.unsafe_memory=(n.bus_active&&n.bus_data)||(n.m.valid&&n.m.e.mem)||(n.w.valid&&n.w.e.mem);
  end
  if(n.fatal)begin n.retire=0;write_rf=0;md_cancel=1;end
  injection='0;
  for(j=0;j<STATE_BITS;j=j+1)if(j/512==fi_index)injection[j]=fi_mask[j%512];
  core_ack=rst_n&&FI_ENABLE&&fi_valid&&fi_target>=5&&fi_target<=7&&fi_index<WINDOWS&&fi_mask!=0;
  if(fi_index==WINDOWS-1&&(fi_mask>>(STATE_BITS%512==0?512:STATE_BITS%512))!=0)core_ack=0;
  if(PARITY_REPLAY&&fi_target!=5&&trusted(injection)!=injection)core_ack=0;
  rf_ack=rst_n&&FI_ENABLE&&fi_valid&&fi_index<32&&fi_mask!=0&&((!RF_TMR&&fi_target==1&&(fi_mask>>39)==0)||(RF_TMR&&fi_target>=2&&fi_target<=4&&(fi_mask>>32)==0));
  fi_rf_base=rf[fi_index[4:0]];
  if(s.scrub==fi_index&&scrubbed.corrected)fi_rf_base=scrubbed.repaired;
  if(s.d.valid&&s.d.insn[19:15]==fi_index&&ra.corrected)fi_rf_base=ra.repaired;
  if(s.d.valid&&s.d.insn[24:20]==fi_index&&rb.corrected)fi_rf_base=rb.repaired;
  if(write_rf&&write_rd==fi_index)fi_rf_base=word_encode(write_value);
  if(fi_index==0)fi_rf_base=word_encode(0);
  fi_ack=core_ack||rf_ack||md_ack0||md_ack1;
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   c0<='0;c1<='0;c2<='0;payload_parity<=0;replay0<='0;replay1<='0;replay2<='0;
   c0.fetch_pc<=(MONITOR_CONTROL?boot_pc:RESET_PC);c1.fetch_pc<=UNPROTECTED?0:(MONITOR_CONTROL?boot_pc:RESET_PC);c2.fetch_pc<=UNPROTECTED?0:(MONITOR_CONTROL?boot_pc:RESET_PC);
   c0.arch_pc<=(MONITOR_CONTROL?boot_pc:RESET_PC);c1.arch_pc<=UNPROTECTED?0:(MONITOR_CONTROL?boot_pc:RESET_PC);c2.arch_pc<=UNPROTECTED?0:(MONITOR_CONTROL?boot_pc:RESET_PC);
   c0.mtimecmp<='1;c1.mtimecmp<=UNPROTECTED?0:'1;c2.mtimecmp<=UNPROTECTED?0:'1;
   for(integer z=0;z<32;z=z+1)begin rf[z]<=word_encode(0);tmr0[z]<=0;tmr1[z]<=0;tmr2[z]<=0;end
  end else begin
   replay0<=PARITY_REPLAY?recovery_next:'0;replay1<=PARITY_REPLAY?recovery_next:'0;replay2<=PARITY_REPLAY?recovery_next:'0;
   c0<=n;c1<=UNPROTECTED?'0:(PARITY_REPLAY?trusted(n):n);c2<=UNPROTECTED?'0:(PARITY_REPLAY?trusted(n):n);payload_parity<=PARITY_REPLAY?stage_parity(n):0;
   if(core_ack)case(fi_target)5:c0<=n^injection;6:c1<=(PARITY_REPLAY?trusted(n):n)^injection;7:c2<=(PARITY_REPLAY?trusted(n):n)^injection;endcase
   if(RF_TMR)begin
    for(integer z=0;z<32;z=z+1)begin
     tmr0[z]<=(tmr0[z]&tmr1[z])|(tmr0[z]&tmr2[z])|(tmr1[z]&tmr2[z]);
     tmr1[z]<=(tmr0[z]&tmr1[z])|(tmr0[z]&tmr2[z])|(tmr1[z]&tmr2[z]);
     tmr2[z]<=(tmr0[z]&tmr1[z])|(tmr0[z]&tmr2[z])|(tmr1[z]&tmr2[z]);
    end
   end else begin
    if(scrubbed.corrected&&!scrubbed.uncorrectable)rf[s.scrub]<=scrubbed.repaired;
    if(s.d.valid&&ra.corrected&&!ra.uncorrectable)rf[s.d.insn[19:15]]<=ra.repaired;
    if(s.d.valid&&rb.corrected&&!rb.uncorrectable)rf[s.d.insn[24:20]]<=rb.repaired;
   end
   if(write_rf&&!n.fatal)begin rf[write_rd]<=word_encode(write_value);tmr0[write_rd]<=RF_TMR?write_value:0;tmr1[write_rd]<=RF_TMR?write_value:0;tmr2[write_rd]<=RF_TMR?write_value:0;end
   rf[0]<=word_encode(0);tmr0[0]<=0;tmr1[0]<=0;tmr2[0]<=0;
   if(rf_ack)case(fi_target)
    1:rf[fi_index]<=fi_rf_base^fi_mask[38:0];
    2:tmr0[fi_index]<=((write_rf&&write_rd==fi_index)?write_value:((tmr0[fi_index]&tmr1[fi_index])|(tmr0[fi_index]&tmr2[fi_index])|(tmr1[fi_index]&tmr2[fi_index])))^fi_mask[31:0];
    3:tmr1[fi_index]<=((write_rf&&write_rd==fi_index)?write_value:((tmr0[fi_index]&tmr1[fi_index])|(tmr0[fi_index]&tmr2[fi_index])|(tmr1[fi_index]&tmr2[fi_index])))^fi_mask[31:0];
    4:tmr2[fi_index]<=((write_rf&&write_rd==fi_index)?write_value:((tmr0[fi_index]&tmr1[fi_index])|(tmr0[fi_index]&tmr2[fi_index])|(tmr1[fi_index]&tmr2[fi_index])))^fi_mask[31:0];
   endcase
  end
 end
`ifdef FORMAL
 reg past_valid=0;
 always @(posedge clk)begin
  past_valid<=1;
  if(rst_n)begin
   assert(!fatal||!req);
   if(id_jump_redirect)begin
    assert(n.x.valid&&n.x.pc==s.d.pc&&!s.d.trap);
    assert(n.fetch_pc==jump_target0&&!n.f.valid&&!n.half_valid);
    if(s.bus_active&&!s.bus_data&&!ready)assert(n.bus_kill);
   end
   if(s.w.valid&&s.w.trap)begin assert(!s.bus_data||!req);assert(!write_rf);end
   if(s.bus_active&&s.bus_data&&!fatal)assert(s.m.valid&&s.m.e.mem);
   if(retire_valid&&rvfi_trap)assert(!s.retired.e.rd_we&&!s.retired.e.mem);
   if(retire_valid&&retire_rd==0)assert(retire_result==0);
   if(!UNPROTECTED&&past_valid&&$past(rst_n&&!core_ack))assert(PARITY_REPLAY?(trusted(c0)==c1&&c1==c2):(c0==c1&&c0==c2));
  end
 end
`endif
endmodule
