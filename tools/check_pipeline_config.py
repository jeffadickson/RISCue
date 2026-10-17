from pipeline_config import configuration
assert configuration()['pipeline_protection']=='TMR'
assert configuration('TMR','0')['fi_abi']==2
assert configuration('PARITY_REPLAY','1')['fi_abi']==3
for mode,exp in [('bad','1'),('PARITY_REPLAY','0'),('TMR','2')]:
 try:configuration(mode,exp)
 except ValueError:pass
 else:raise AssertionError((mode,exp))
print('PASS pipeline build provenance and negative selection tests')
