package riscue_pipeline_pkg;
 import ft_pkg::*;
 typedef struct packed {
  logic valid,trap,serial,csr,csr_write,mret,fencei;
  logic [31:0] pc,raw,insn,cause,tval,a,b,csr_value,mem_data;
  logic [2:0] bytes;
  logic [4:0] rs1,rs2;
  logic [11:0] csr_addr;
  exec_t e;
 } slot_t;
 typedef struct packed {
  // Architectural debug state participates in the pipeline TMR record.
  logic debug_halted,debug_step,debug_step_issued,debug_ebreakm;
  logic [2:0] debug_cause;
  slot_t f,d,x,m,w;
  logic [31:0] fetch_pc,arch_pc,half_word;
  logic half_valid,bus_active,bus_data,bus_half,bus_kill,bus_cooldown;
  logic [31:0] bus_pc,bus_addr,bus_wdata,bus_ctrl,bus_wait;
  logic x_started,x_done;logic [31:0] x_result;
  logic fatal,trap_pulse,irq_drain;logic [31:0] irq_cause;
  logic irq_meta,irq_sync;
  logic [31:0] mtvec,mepc,mcause,mtval,mscratch,mie;
  logic mie_global,mpie,msip;
  logic [63:0] mcycle,minstret,mtime,mtimecmp,order;
  logic [4:0] scrub;
  logic retire,retire_trap,retire_intr,interrupt_next;
  slot_t retired;
 } state_t;
 typedef struct packed {
  logic busy,done,fatal;logic [2:0] op;logic [5:0] count;
  logic [31:0] quotient,divisor,result,original;
  logic [32:0] remainder;
  logic qnegative,rnegative;
  logic signed [32:0] a,b;
  logic signed [65:0] product;
 } md_state_t;
 localparam integer CORE_BITS=$bits(state_t), CORE_WINDOWS=(CORE_BITS+511)/512, MD_BITS=$bits(md_state_t);
 function automatic integer fi_width(input bit use_tmr,input integer words,input logic [3:0] target,input logic [31:0] index);
  begin
   fi_width=0;
   case(target)
    1:if(!use_tmr&&index<32)fi_width=39;
    2,3,4:if(use_tmr&&index<32)fi_width=32;
    5,6,7:if(index<CORE_WINDOWS)fi_width=index==CORE_WINDOWS-1?CORE_BITS-(CORE_WINDOWS-1)*512:512;
    8:if(index<words)fi_width=39;
    9,10,11:if(index==0)fi_width=35;
    12,13,14:if(index==0)fi_width=321;
    15:if(index==0||index==1||index==2||index==256||index==257||index==258)fi_width=MD_BITS;
    default:fi_width=0;
   endcase
  end
 endfunction
endpackage
