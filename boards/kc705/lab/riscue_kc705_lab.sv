module riscue_kc705_lab #(parameter integer WORDS=1024,parameter bit RF_TMR=0)(
 input logic clk,rst_n,
 input logic external_trigger,
 input logic core_fatal,
 input logic retire_valid,
 input logic [31:0] retire_pc,
 input logic [31:0] pc,
 input logic [15:0] flags,
 input logic [31:0] cause,
 input logic [31:0] corrected_count,
 input logic [31:0] uncorrectable_count,
 input logic [31:0] disagreement_count,
 input logic [31:0] fatal_count,
 input logic fi_ack,
 input logic event_valid,
 input logic [15:0] first_flags,
 input logic [31:0] first_pc,
 input logic [31:0] first_address,
 input logic [15:0] last_flags,
 input logic [31:0] report_last_pc,
 input logic [31:0] last_address,
 output wire core_reset,output logic fi_valid,output logic [3:0] fi_target,output logic [31:0] fi_index,output logic [511:0] fi_mask
);
 wire vio_reset;assign core_reset=vio_reset;
 logic request_toggle;
 logic arm;
 logic [3:0] command_target;
 logic [31:0] command_index;
 logic [255:0] mask_low;
 logic [255:0] mask_high;
 logic [31:0] command_delay;
 logic [15:0] command_count;
 logic [31:0] command_gap;
 logic [1:0] command_trigger_kind;
 logic [31:0] command_trigger_pc;
 logic [31:0] command_index_step;
 logic command_rotate;
 logic command_stop_on_fatal;
 logic done_toggle;
 logic busy;
 logic [7:0] status;
 logic [15:0] accepted;
 logic [15:0] attempted;
 logic [31:0] last_pc;
 logic [63:0] last_cycle;
 logic controller_disagreement;
 logic [31:0] configuration;
 logic [63:0] trigger_cycle;
 logic controller_error_sticky;
 logic [511:0] command_mask;
 assign command_mask={mask_high,mask_low};
 assign configuration={16'(WORDS),8'd2,6'b0,1'b1,RF_TMR};
 fi_campaign_controller #(.WORDS(WORDS),.RF_TMR(RF_TMR)) controller(
 .clk(clk),
 .rst_n(rst_n),
 .arm(arm),
 .request_toggle(request_toggle),
 .core_reset(vio_reset),
 .core_fatal(core_fatal),
 .external_trigger(external_trigger),
 .command_target(command_target),
 .command_index(command_index),
 .command_mask(command_mask),
 .command_delay(command_delay),
 .command_gap(command_gap),
 .command_index_step(command_index_step),
 .command_trigger_pc(command_trigger_pc),
 .command_count(command_count),
 .command_trigger_kind(command_trigger_kind),
 .command_rotate(command_rotate),
 .command_stop_on_fatal(command_stop_on_fatal),
 .retire_valid(retire_valid),
 .retire_pc(retire_pc),
 .pc(pc),
 .fi_ack(fi_ack),
 .fi_valid(fi_valid),
 .fi_target(fi_target),
 .fi_index(fi_index),
 .fi_mask(fi_mask),
 .busy(busy),
 .done_toggle(done_toggle),
 .controller_disagreement(controller_disagreement),
 .controller_error_sticky(controller_error_sticky),
 .status(status),
 .accepted(accepted),
 .attempted(attempted),
 .last_pc(last_pc),
 .last_cycle(last_cycle),
 .trigger_cycle(trigger_cycle));
 riscue_test_vio test_vio(.clk(clk),
 .probe_out0(request_toggle),
 .probe_out1(arm),
 .probe_out2(command_target),
 .probe_out3(command_index),
 .probe_out4(mask_low),
 .probe_out5(mask_high),
 .probe_out6(command_delay),
 .probe_out7(command_count),
 .probe_out8(command_gap),
 .probe_out9(command_trigger_kind),
 .probe_out10(command_trigger_pc),
 .probe_out11(command_index_step),
 .probe_out12(command_rotate),
 .probe_out13(command_stop_on_fatal),
 .probe_out14(vio_reset),
 .probe_in0(done_toggle),
 .probe_in1(busy),
 .probe_in2(status),
 .probe_in3(accepted),
 .probe_in4(attempted),
 .probe_in5(last_pc),
 .probe_in6(last_cycle),
 .probe_in7(pc),
 .probe_in8(flags),
 .probe_in9(cause),
 .probe_in10(corrected_count),
 .probe_in11(uncorrectable_count),
 .probe_in12(disagreement_count),
 .probe_in13(fatal_count),
 .probe_in14(controller_disagreement),
 .probe_in15(fi_index),
 .probe_in16(configuration),
 .probe_in17(trigger_cycle),
 .probe_in18(first_flags),
 .probe_in19(first_pc),
 .probe_in20(first_address),
 .probe_in21(last_flags),
 .probe_in22(report_last_pc),
 .probe_in23(last_address),
 .probe_in24(controller_error_sticky));
 wire [255:0] trace={pc,retire_pc,cause,corrected_count,uncorrectable_count,disagreement_count,fatal_count,flags,12'b0,retire_valid,fi_valid,fi_ack,event_valid};
 riscue_test_ila test_ila(.clk(clk),
 .probe0(trace),
 .probe1(last_cycle),
 .probe2(fi_index),
 .probe3(fi_target),
 .probe4(status),
 .probe5(accepted),
 .probe6(fi_valid),
 .probe7(event_valid),
 .probe8(core_fatal),
 .probe9(controller_disagreement));
endmodule
