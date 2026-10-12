// KC705 bring-up wrapper. Board diagnostics/clock/reset are outside the SEU guarantee.
module riscue_kc705 #(
 parameter integer WORDS=1024, CLK_DIV=100,
 parameter bit RF_TMR=0,FI_ENABLE=0,INSTRUMENTED=0,
 parameter INIT_FILE="firmware.hex"
)(input wire sys_clk_p,sys_clk_n,cpu_reset,fault_button,
 output wire [7:0] led,output wire uart_tx);
 localparam integer CLOCK_HZ=1000000000/CLK_DIV;
 localparam integer DEBOUNCE_TICKS=CLOCK_HZ/100;
 wire input_clk,feedback,feedback_buf,clock_raw,clk,locked;
 IBUFDS clock_input(.I(sys_clk_p),.IB(sys_clk_n),.O(input_clk));
 MMCME2_BASE #(.CLKIN1_PERIOD(5.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(5.0),
  .CLKOUT0_DIVIDE_F(CLK_DIV*1.0),.BANDWIDTH("OPTIMIZED")) clock_mmcm(
  .CLKIN1(input_clk),.CLKFBIN(feedback_buf),.RST(cpu_reset),.PWRDWN(1'b0),
  .CLKFBOUT(feedback),.CLKOUT0(clock_raw),.LOCKED(locked));
 BUFG clock_feedback(.I(feedback),.O(feedback_buf));
 BUFG core_clock(.I(clock_raw),.O(clk));
 wire raw_reset=cpu_reset||!locked;
 (* ASYNC_REG="TRUE" *) logic [3:0] reset_pipe=0;
 always @(posedge clk or posedge raw_reset)
  if(raw_reset)reset_pipe<=0;else reset_pipe<={reset_pipe[2:0],1'b1};
 wire rst_n=reset_pipe[3];
 (* ASYNC_REG="TRUE" *) logic [1:0] fault_sync;
 logic stable_button,inject;logic [31:0] debounce;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin fault_sync<=0;stable_button<=0;debounce<=0;inject<=0;end
  else begin
   fault_sync<={fault_sync[0],fault_button};inject<=0;
   if(fault_sync[1]==stable_button)debounce<=0;
   else if(debounce==DEBOUNCE_TICKS-1)begin
    stable_button<=fault_sync[1];debounce<=0;inject<=fault_sync[1];
   end else debounce<=debounce+1;
  end
 end
 wire halted,fatal,trap,retire_valid,fi_ack;
 wire [31:0] pc,cause,tval,corrected_count,uncorrectable_count,disagreement_count,fatal_count;
 wire [15:0] flags,first_flags,last_flags;
 wire [31:0] retire_pc,first_pc,first_address,last_pc,last_address;
 wire event_valid,lab_core_reset,fi_valid;
 wire [3:0] fi_target;wire [31:0] fi_index;wire [511:0] fi_mask;
 wire soc_rst_n=rst_n&&!lab_core_reset;
 generate if(INSTRUMENTED)begin:instrumented
  riscue_kc705_lab #(.WORDS(WORDS),.RF_TMR(RF_TMR)) lab(
   .clk(clk),.rst_n(rst_n),.external_trigger(inject),.core_fatal(fatal),
   .retire_valid(retire_valid),.retire_pc(retire_pc),.pc(pc),.flags(flags),.cause(cause),
   .corrected_count(corrected_count),.uncorrectable_count(uncorrectable_count),
   .disagreement_count(disagreement_count),.fatal_count(fatal_count),.fi_ack(fi_ack),.event_valid(event_valid),
   .first_flags(first_flags),.first_pc(first_pc),.first_address(first_address),
   .last_flags(last_flags),.report_last_pc(last_pc),.last_address(last_address),
   .core_reset(lab_core_reset),.fi_valid(fi_valid),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask));
 end else begin:production
  assign lab_core_reset=0;assign fi_valid=FI_ENABLE&&inject;
  assign fi_target=8;assign fi_index=WORDS-1;assign fi_mask=512'd1;
 end endgenerate
 (* keep_hierarchy="yes" *) riscue_pipeline_soc #(.WORDS(WORDS),.INIT_FILE(INIT_FILE),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE)) soc(
  .clk(clk),.rst_n(soc_rst_n),.halted(halted),.fatal(fatal),.trap(trap),.pc(pc),.trap_cause(cause),.trap_value(tval),
  .external_irq(1'b0),.retire_valid(retire_valid),.retire_pc(retire_pc),
  .fi_valid(FI_ENABLE&&fi_valid),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(fi_ack),
  .event_valid(event_valid),.first_flags(first_flags),.first_pc(first_pc),.first_address(first_address),
  .last_flags(last_flags),.last_pc(last_pc),.last_address(last_address),
  .sticky_flags(flags),.corrected_count(corrected_count),.uncorrectable_count(uncorrectable_count),
  .disagreement_count(disagreement_count),.fatal_count(fatal_count));
 logic [23:0] heartbeat;logic [31:0] activity;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin heartbeat<=0;activity<=0;end
  else begin
   heartbeat<=heartbeat+1;
   if(retire_valid)activity<=CLOCK_HZ/20;else if(activity!=0)activity<=activity-1;
  end
 end
 assign led={trap,flags[2]|flags[10]|flags[15],flags[1]|flags[9]|flags[11],flags[0]|flags[8],fatal,halted,(activity!=0),heartbeat[23]};
 riscue_status_uart #(.CLOCK_HZ(CLOCK_HZ)) telemetry(
  .clk(clk),.rst_n(rst_n),.halted(halted),.fatal(fatal),.trap(trap),.retire_valid(retire_valid),
  .pc(pc),.cause(cause),.tval(tval),.flags(flags),.corrected_count(corrected_count),
  .uncorrectable_count(uncorrectable_count),.disagreement_count(disagreement_count),.fatal_count(fatal_count),.tx(uart_tx));
endmodule
