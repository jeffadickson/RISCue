// Separate FMC-LPC JTAG laboratory target; does not replace the UART monitor.
module riscue_kc705_debug #(parameter bit RF_TMR=0)(
 input wire sys_clk_p,sys_clk_n,cpu_reset,
 input wire debug_tck,debug_tms,debug_tdi,output wire debug_tdo,
 output wire [7:0] led
);
 wire input_clk,feedback,feedback_buf,clock_raw,clk,locked,tck;
 IBUFDS clock_input(.I(sys_clk_p),.IB(sys_clk_n),.O(input_clk));
 MMCME2_BASE #(.CLKIN1_PERIOD(5.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(5.0),.CLKOUT0_DIVIDE_F(100.0)) clock_mmcm(
  .CLKIN1(input_clk),.CLKFBIN(feedback_buf),.RST(cpu_reset),.PWRDWN(1'b0),.CLKFBOUT(feedback),.CLKOUT0(clock_raw),.LOCKED(locked));
 BUFG clock_feedback(.I(feedback),.O(feedback_buf));BUFG core_clock(.I(clock_raw),.O(clk));
 BUFG debug_clock(.I(debug_tck),.O(tck));
 wire raw_reset=cpu_reset||!locked;
 (* ASYNC_REG="TRUE" *) reg [3:0] reset_pipe=0;
 always @(posedge clk or posedge raw_reset)if(raw_reset)reset_pipe<=0;else reset_pipe<={reset_pipe[2:0],1'b1};
 wire debug_halted,fatal,trap,retire_valid;wire [31:0] pc,retire_pc,retire_insn;
 riscue_debug_soc #(.RF_TMR(RF_TMR)) soc(.clk(clk),.rst_n(reset_pipe[3]),.tck(tck),.tms(debug_tms),.tdi(debug_tdi),.tdo(debug_tdo),
  .external_irq(1'b0),.debug_halted(debug_halted),.fatal(fatal),.trap(trap),.retire_valid(retire_valid),.pc(pc),.retire_pc(retire_pc),.retire_insn(retire_insn));
 assign led={pc[5:2],retire_valid,trap,fatal,debug_halted};
endmodule
