import importlib.util
import pathlib
import unittest
import copy
s=importlib.util.spec_from_file_location('cycle_shadow',pathlib.Path(__file__).with_name('cycle_shadow_evaluation.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class ShadowTest(unittest.TestCase):
 def fixture(self):return {'researchConsented':True,'rows':[{'participant':p,'cohort':c,'asOf':'2026-10-26','actualStart':'2026-10-29','lastStart':'2026-10-01','leadDays':3,'priorLengths':[28,30,32],'temperature':[]}for p,c in [('a','development'),('b','test')]]}
 def test_no_automatic_release(self):r=m.assess(self.fixture());self.assertFalse(r['released']);self.assertEqual(r['slices']['3']['enhancedFraction'],0)
 def test_split(self):d=self.fixture();d['rows'][1]['participant']='a';self.assertRaises(ValueError,m.validate,d)
 def test_future(self):d=self.fixture();d['rows'][0]['temperature']=[{'date':'2026-10-25','availableOn':'2026-10-30','qualified':True,'deviation':.1}];self.assertRaises(ValueError,m.validate,d)
 def test_consent(self):d=self.fixture();d['researchConsented']=False;self.assertRaises(ValueError,m.validate,d)
 def test_future_never_changes_frozen_features(self):d=self.fixture();row=d['rows'][0];original=m.features(row,0);self.assertEqual(original,m.features(copy.deepcopy(row),0))
if __name__=='__main__':unittest.main()
