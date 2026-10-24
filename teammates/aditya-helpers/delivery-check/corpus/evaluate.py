
import json,sys
from collections import defaultdict
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
from delivery_check import compare
BASE=Path(__file__).resolve().parent

def evaluate(cases):
    by_verdict=defaultdict(lambda:{'correct':0,'total':0});errors=[];critical_errors=[];critical_total=0
    for case in cases:
        out=compare(case['input']);actual=out['lines'][0]['verdict'];gold=case['gold']
        correct=actual==gold and len(out['extra'])==case['goldExtra']
        by_verdict[gold]['total']+=1;by_verdict[gold]['correct']+=correct
        if not correct:errors.append({'id':case['id'],'gold':gold,'actual':actual,'extra':len(out['extra'])})
        if gold in {'strength_differs','brand_differs','expired','missing'}:
            critical_total+=1
            if actual in {'ok','likely_ok'}:critical_errors.append({'id':case['id'],'gold':gold,'actual':actual})
    for value in by_verdict.values():value['accuracy']=value['correct']/value['total']
    return {'synthetic':True,'cases':len(cases),'correct':len(cases)-len(errors),'accuracy':(len(cases)-len(errors))/len(cases) if cases else None,'perVerdict':dict(by_verdict),'criticalCases':critical_total,'dangerousErrors':len(critical_errors),'dangerousErrorRate':len(critical_errors)/critical_total if critical_total else None,'criticalErrorCases':critical_errors,'errors':errors}

if __name__=='__main__':
    report=evaluate(json.loads((BASE/'cases.json').read_text(encoding='utf-8')))
    (BASE/'metrics.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,indent=2))
