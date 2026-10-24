
"""Deterministic synthetic corpus; gold labels are scenarios, not engine outputs."""
import copy,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
from delivery_check.core import load_catalogue,_strength
OUT=Path(__file__).resolve().parent

def make_cases():
    catalogue,_,_=load_catalogue()
    brands=[(b,values) for b,values in sorted(catalogue.items()) if len(b)>=5 and b.isalpha() and len(values)>=2 and all(_strength(v) is not None for v in values)][:30]
    cases=[]
    for n,(brand,values) in enumerate(brands):
        strength=values[0]
        base={'confirmed':[{'itemId':f'item-{n}','name':brand,'strength':strength,'qty':15}],
              'received':[{'brand':brand,'strength':strength,'units':15,'expiry':'2027-08-31'}],
              'options':{'today':'2026-10-24','minMonthsToExpiry':3,'approvedSubstituteBrands':[]}}
        for category,gold in [('correct','ok'),('strength_changed','strength_differs'),('different_real_brand','brand_differs'),('expired','expired'),('expiry_soon','expiry_soon'),('fewer_units','quantity_short'),('missing_item','missing'),('extra_item','ok'),('ocr_one','likely_ok'),('ocr_two','likely_ok'),('missing_expiry','unreadable'),('unknown_strength','unreadable'),('non_latin_garbage','unreadable')]:
            payload=copy.deepcopy(base);received=payload['received'][0];extra=0
            if category=='strength_changed':received['strength']=values[1]
            elif category=='different_real_brand':received.update(brand='DOLO',strength='650')
            elif category=='expired':received['expiry']='2026-09-30'
            elif category=='expiry_soon':received['expiry']='2026-12-31'
            elif category=='fewer_units':received['units']=14
            elif category=='missing_item':payload['received']=[]
            elif category=='extra_item':payload['received'].append({'brand':'DOLO','strength':'650','units':15,'expiry':'2027-08-31'});extra=1
            elif category.startswith('ocr_'):
                candidate=('Q'+brand[1:]) if category=='ocr_one' else ('QX'+brand[2:])
                # Choose an unrecognized token, never relabel a real brand as an OCR error.
                if candidate in catalogue or candidate==brand:
                    candidate=('ZX'+brand[2:]) if category=='ocr_two' else ('Z'+brand[1:])
                assert candidate not in catalogue and candidate!=brand
                received['brand']=candidate
            elif category=='missing_expiry':received['expiry']=None
            elif category=='unknown_strength':received['strength']='999999999'
            elif category=='non_latin_garbage':received.update(brand='अस्पष्ट',strength=None,units=None,expiry=None)
            cases.append({'id':f'{n:02}-{category}','category':category,'input':payload,'gold':gold,'goldExtra':extra})
    return cases

if __name__=='__main__':
    cases=make_cases();(OUT/'cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(f'{len(cases)} synthetic cases written')
