from pipeline_config import configuration
assert configuration()['pipeline_protection']=='TMR'
assert configuration('TMR','0')['fi_abi']==2
assert configuration('PARITY_REPLAY','1')['fi_abi']==3
for mode,exp in [('bad','1'),('PARITY_REPLAY','0'),('TMR','2')]:
 try:configuration(mode,exp)
 except ValueError:pass
 else:raise AssertionError((mode,exp))
print('PASS pipeline build provenance and negative selection tests')

assert configuration('PLAIN','0')['mode_id']==2
assert configuration('PLAIN','0')['fi_abi'] is None
assert '-DRISCUE_PLAIN_MEMORY' in configuration('PLAIN','0')['iverilog_flags']

assert configuration('TMR','0','MULTICYCLE')['fi_abi']==4
assert configuration('PLAIN','0','MULTICYCLE')['fi_abi'] is None
for arch,mode in [('TYPO','TMR'),('MULTICYCLE','PARITY_REPLAY')]:
 try:configuration(mode,'1',arch)
 except ValueError:pass
 else:raise AssertionError((arch,mode))
print('PASS architecture selection and compact FI ABI')
