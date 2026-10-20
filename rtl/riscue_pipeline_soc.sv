module riscue_pipeline_soc #(
 parameter bit MULTICYCLE=`RISCUE_MULTICYCLE,
 parameter integer PIPELINE_PROTECTION=`RISCUE_PIPELINE_PROTECTION,
 parameter bit ALLOW_EXPERIMENTAL_PARITY=`RISCUE_ALLOW_EXPERIMENTAL_PARITY,
 parameter integer WORDS=1024,parameter INIT_FILE="",parameter integer BUS_TIMEOUT=1024,
 parameter bit RF_TMR=0,parameter bit FI_ENABLE=0,EARLY_JUMP=1
)(
 input logic clk,rst_n,external_irq,
 output logic halted,fatal,trap,
 output logic [31:0] trap_cause,trap_value,pc,
 output logic corrected_event,disagreement_event,
 output logic retire_valid,
 output logic [31:0] retire_pc,retire_insn,retire_result,
 output logic [4:0] retire_rd,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output logic fi_ack,
 output logic event_valid,output logic [15:0] sticky_flags,
 output logic [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,
 output logic [31:0] first_pc,first_address,last_pc,last_address,
 output logic [15:0] first_flags,last_flags
);
`ifdef RISCUE_PLAIN_MEMORY
 initial if(PIPELINE_PROTECTION!=2)$fatal(1,"Plain RAM requires PIPELINE_PROTECTION=PLAIN");
 generate if(1)begin: plain
 riscue_pipeline_core #(.MULTICYCLE(MULTICYCLE),.PIPELINE_PROTECTION(2),.BUS_TIMEOUT(BUS_TIMEOUT),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.EARLY_JUMP(EARLY_JUMP)) core(
  .clk(clk),.rst_n(rst_n),.external_irq(external_irq),.req(req),.addr_code(ac),.wdata_code(wc),.ctrl_code(cc),
  .ready(ready),.bus_error(error),.external_fault(1'b0),.rdata_code({7'b0,rd}),
  .halted(halted),.fatal(fatal),.trap(trap),.trap_cause(trap_cause),.trap_value(trap_value),.pc(pc),
  .retire_valid(retire_valid),.retire_pc(retire_pc),.retire_insn(retire_insn),.retire_result(retire_result),.retire_rd(retire_rd),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0));
 wire req;wire [38:0] ac,wc,cc;logic ready,error;logic [31:0] rd;
 logic [31:0] mem[0:WORDS-1];integer i,b;
 initial begin for(i=0;i<WORDS;i=i+1)mem[i]=0;if(INIT_FILE!="")$readmemh(INIT_FILE,mem);end
 always @(posedge clk)begin
  if(!rst_n)begin ready<=0;error<=0;rd<=0;end
  else begin
   ready<=0;error<=0;
   if(req&&!ready)begin
    ready<=1;
    if(ac[31:2]>=WORDS||ac[1:0]!=0||cc[31:5]!=0)begin error<=1;rd<=0;end
    else begin
     rd<=mem[ac[31:2]];
     if(cc[4])for(b=0;b<4;b=b+1)if(cc[b])mem[ac[31:2]][b*8+:8]<=wc[b*8+:8];
    end
   end
  end
 end
 assign corrected_event=0;assign disagreement_event=0;assign fi_ack=0;assign event_valid=0;assign sticky_flags=0;
 assign corrected_count=0;assign uncorrectable_count=0;assign disagreement_count=0;assign fatal_count=0;
 assign first_pc=0;assign first_address=0;assign last_pc=0;assign last_address=0;assign first_flags=0;assign last_flags=0;
 end endgenerate
`else
 initial if(PIPELINE_PROTECTION==2)$fatal(1,"PLAIN SoC requires RISCUE_PLAIN_MEMORY from canonical build flags");
 wire [31:0] compact_bits=$bits(riscue_pipeline_pkg::compact_state_t);
 wire [31:0] compact_windows=(compact_bits+511)/512;
 wire [31:0] injection_width=(MULTICYCLE&&fi_target>=5&&fi_target<=7)?
  (fi_index<compact_windows?(fi_index==compact_windows-1?compact_bits-(compact_windows-1)*512:512):0):
  riscue_pipeline_pkg::fi_width(RF_TMR,WORDS,fi_target,fi_index);
 wire fi_dispatch=rst_n&&fi_valid&&injection_width!=0&&fi_mask!=0&&(fi_mask>>injection_width)==0;
 logic req,ready,error,mem_fatal,mem_ce,mem_dis,core_ce,core_dis,report_dis;
 logic core_ack,mem_ack,report_ack;
 logic [7:0] core_flags,mem_flags;logic [31:0] core_address,mem_address;
 logic [38:0] addr_code,wdata_code,ctrl_code,rdata_code;
 riscue_pipeline_core #(.MULTICYCLE(MULTICYCLE),.PIPELINE_PROTECTION(PIPELINE_PROTECTION),.ALLOW_EXPERIMENTAL_PARITY(ALLOW_EXPERIMENTAL_PARITY),.BUS_TIMEOUT(BUS_TIMEOUT),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.EARLY_JUMP(EARLY_JUMP)) core(
  .clk(clk),.rst_n(rst_n),.external_irq(external_irq),.req(req),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
  .ready(ready),.bus_error(error),.external_fault(mem_fatal),.rdata_code(rdata_code),
  .halted(halted),.fatal(fatal),.trap(trap),.trap_cause(trap_cause),.trap_value(trap_value),.pc(pc),
  .corrected_event(core_ce),.disagreement_event(core_dis),.retire_valid(retire_valid),
  .retire_pc(retire_pc),.retire_insn(retire_insn),.retire_result(retire_result),.retire_rd(retire_rd),
  .fi_valid(fi_dispatch),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(core_ack),
  .event_flags(core_flags),.event_address(core_address));
 ft_ecc_ram #(.WORDS(WORDS),.INIT_FILE(INIT_FILE),.FI_ENABLE(FI_ENABLE),.FAIL_STOP_DED(1)) ram(
  .clk(clk),.rst_n(rst_n),.req(req),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
  .ready(ready),.error(error),.rdata_code(rdata_code),.corrected_event(mem_ce),.fatal(mem_fatal),.disagreement_event(mem_dis),
  .fi_valid(fi_dispatch),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(mem_ack),
  .event_flags(mem_flags),.event_address(mem_address));
 ft_event_monitor #(.FI_ENABLE(FI_ENABLE)) reporter(
  .clk(clk),.rst_n(rst_n),.flags({mem_flags,core_flags}),.observation_pc(pc),
  .observation_address((mem_flags!=0)?mem_address:core_address),
  .fi_valid(fi_dispatch),.fi_target(fi_target),.fi_mask(fi_mask),.fi_ack(report_ack),
  .event_valid(event_valid),.sticky_flags(sticky_flags),.corrected_count(corrected_count),
  .uncorrectable_count(uncorrectable_count),.disagreement_count(disagreement_count),.fatal_count(fatal_count),
  .first_pc(first_pc),.first_address(first_address),.first_flags(first_flags),
  .last_pc(last_pc),.last_address(last_address),.last_flags(last_flags),.report_disagreement(report_dis));
 assign corrected_event=core_ce|mem_ce;
 assign disagreement_event=core_dis|mem_dis|report_dis;
 assign fi_ack=core_ack|mem_ack|report_ack;
`endif
endmodule
