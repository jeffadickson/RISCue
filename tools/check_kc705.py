#!/usr/bin/env python3
"""Compile-only check of both KC705 variants using nonphysical vendor stubs."""
import subprocess,os
from pathlib import Path
root=Path(__file__).resolve().parents[1];os.chdir(root);Path('build').mkdir(exist_ok=True); rtl=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core','ft_ecc_ram','ft_event_monitor','riscue_pipeline_soc','fi_campaign_controller','riscue_axi_master_bridge','riscue_axi_core','riscue_axi_ecc_ram','riscue_serial_monitor','riscue_monitor_soc']
for mode in (0,1):
 with open(f'build/monitor-board-{mode}.log','w') as log:
  subprocess.run(['iverilog','-g2012','-s','riscue_kc705',f'-Priscue_kc705.INSTRUMENTED={mode}',f'-Priscue_kc705.FI_ENABLE={mode}','-o',f'build/monitor-board-{mode}',*[f'rtl/{x}.sv' for x in rtl],*[f'boards/kc705/{x}.sv' for x in ['uart_tx','uart_rx','status_uart','riscue_kc705','monitor_top']], 'boards/kc705/lab/riscue_kc705_lab.sv','tests/kc705_vendor_stubs.sv'],check=True,stdout=log,stderr=subprocess.STDOUT)
 print('PASS board compile-only vendor stubs, instrumented=',mode)
