"""Check registered native Catch XML cases; JUnit SECTION nodes are not cases."""
from pathlib import Path
import argparse,json,re,xml.etree.ElementTree as ET
SPECS={
 'context':(15,4,{'capacity_fallback'},['tests/filament_group/test_filament_group_context.cpp']),
 'capacity':(84,11,{'capacity_fallback','enum_capacity_fallback'},['tests/filament_group/test_filament_group_context.cpp','tests/filament_group/test_filament_enum_capacity.cpp']),
 'enum-map':(263,4,{'EnumMaps'},['tests/libslic3r/test_config_enum_maps.cpp']),
 'cuda-buffer':(145,17,{'CudaDispatchBuffers'},['tests/libslic3r/test_cuda_dispatch_buffers.cpp'])}
def case_names(repo,kind):
 assertions,count,tags,paths=SPECS[kind];names=[]
 for path in paths:
  text=(Path(repo)/path).read_text(encoding='utf-8-sig')
  for name,rawtags in re.findall(r'TEST_CASE\s*\(\s*"([^"\n]+)"\s*,\s*"([^"\n]*)"',text):
   if tags.intersection(re.findall(r'\[([^\]]+)\]',rawtags)):names.append(name)
 if len(names)!=count or len(set(names))!=count:raise ValueError('Source registered case manifest changed')
 return names
def verify(xml,repo,kind):
 assertions,count,_,_=SPECS[kind];expected=case_names(repo,kind);root=ET.parse(xml).getroot()
 if root.tag not in ('Catch','Catch2TestRun'):raise ValueError('Native Catch XML required; JUnit cardinality is not registered cases')
 nodes=root.findall('.//TestCase');actual=[n.get('name') for n in nodes]
 if len(actual)!=count or len(set(actual))!=count or set(actual)!=set(expected):raise ValueError('Actual source-bound registered case identities differ')
 for node in nodes:
  result=node.find('OverallResult')
  if result is None or result.get('success')!='true':raise ValueError('Registered test case failed or lacks result')
 for element,total in [('OverallResults',assertions),('OverallResultsCases',count)]:
  result=root.find(element)
  if result is None:raise ValueError('Native Catch run totals missing')
  if int(result.get('successes','-1'))!=total or int(result.get('failures','-1'))!=0 or int(result.get('expectedFailures','-1'))!=0:raise ValueError('Actual native Catch totals differ')
 return {'status':'SOURCE_BOUND_NATIVE_CATCH_PASS','kind':kind,'successful_assertions':assertions,'registered_cases':count,'case_names':actual,'GPU_hardware_or_speedup_proof':False}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--xml',required=True);parser.add_argument('--repo',default='.');parser.add_argument('--kind',choices=SPECS,required=True);args=parser.parse_args()
 print(json.dumps(verify(args.xml,args.repo,args.kind)))
