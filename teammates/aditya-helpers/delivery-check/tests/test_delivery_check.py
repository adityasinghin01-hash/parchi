
import copy,importlib.util,json,re
from datetime import date
from pathlib import Path
import pytest
from delivery_check import compare,parse_pack_text,to_problem_helper_input
from delivery_check.core import parse_expiry,add_months,load_catalogue,distance,normalise_brand
MODULE=Path(__file__).resolve().parents[1]
EXAMPLE=json.loads((MODULE/'example.json').read_text(encoding='utf-8'))
CASES=json.loads((MODULE/'corpus/cases.json').read_text(encoding='utf-8'))
BANNED=re.compile(r'\b(safe|unsafe|dangerous|dose|take this|side effect|cure)\b',re.I)

def payload(**pack):
    p=copy.deepcopy(EXAMPLE)
    p['received']=[{'brand':'DOLO','strength':'650','units':15,'expiry':'2027-08-31',**pack}]
    return p

def verdict(p):return compare(p)['lines'][0]['verdict']

@pytest.mark.parametrize('case',CASES,ids=lambda c:c['id'])
def test_synthetic_gold(case):
    out=compare(case['input'])
    assert out['lines'][0]['verdict']==case['gold']
    assert len(out['extra'])==case['goldExtra']
    assert not BANNED.search(json.dumps(out,ensure_ascii=False))
    if case['gold'] in {'strength_differs','brand_differs','expired','missing'}:
        assert out['lines'][0]['verdict'] not in {'ok','likely_ok'}

def test_corpus_dangerous_error_rate_and_reproducibility():
    spec=importlib.util.spec_from_file_location('make_delivery_corpus',MODULE/'corpus/make_corpus.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    assert mod.make_cases()==CASES and len(CASES)>=300
    metrics=json.loads((MODULE/'corpus/metrics.json').read_text(encoding='utf-8'))
    assert metrics['dangerousErrors']==0 and metrics['criticalCases']==120
    assert metrics['correct']==metrics['cases']==390

@pytest.mark.parametrize('raw,brand,strength,units,expiry,batch',[
 ('DOLO 650 Tablet strip of 15 EXP 08/2027 B.No ABC123','DOLO','650',15,'2027-08-31','ABC123'),
 ('Dolo 650mg 15 tablets Exp. 08/27 Batch X1','DOLO','650 mg',15,'2027-08-31','X1'),
 ('AZITHRAL 500 mg 6 caps Expiry JAN 2028 Batch No. Z9','AZITHRAL','500 mg',6,'2028-01-31','Z9'),
 ('ALPRAX .5 mg strip of 10 EXP Feb-28 B.No L2','ALPRAX','.5 mg',10,'2028-02-29','L2'),
 ('ALPRAX 0.5 mg 10 tablets EXP 02/2027 Batch B3','ALPRAX','0.5 mg',10,'2027-02-28','B3'),
 ('Brand: DOLO 650 strip of 15 Exp 12/26 Batch A9','DOLO','650',15,'2026-12-31','A9'),
 ('DOLO 650 10 tabs EXP Mar 2027','DOLO','650',10,'2027-03-31',None),
 ('DOLO 650 15 tablets EXP APR-27','DOLO','650',15,'2027-04-30',None),
 ('DOLO 650 15 tablets EXP May 2027','DOLO','650',15,'2027-05-31',None),
 ('DOLO 650 15 tablets EXP JUN-27','DOLO','650',15,'2027-06-30',None),
 ('DOLO 650 15 tablets EXP JUL 2027','DOLO','650',15,'2027-07-31',None),
 ('DOLO 650 15 tablets EXP Aug-27','DOLO','650',15,'2027-08-31',None),
 ('DOLO 650 15 tablets EXP SEP 2027','DOLO','650',15,'2027-09-30',None),
 ('DOLO 650 15 tablets EXP OCT-27','DOLO','650',15,'2027-10-31',None),
 ('DOLO 650 15 tablets EXP November 2027','DOLO','650',15,'2027-11-30',None),
 ('DOLO 650 15 tablets EXP DEC-27','DOLO','650',15,'2027-12-31',None),
 ('DOLO 650 15 tablets expiry: 01/2028','DOLO','650',15,'2028-01-31',None),
 ('DOLO 650 15 tablets EXP: 13/2027','DOLO','650',15,None,None),
 ('DOLO 650 15 tablets EXP: 00/2027','DOLO','650',15,None,None),
 ('DOLO 650 15 tablets','DOLO','650',15,None,None),
 ('DOLO 650 EXP 08/2027','DOLO','650',None,'2027-08-31',None),
 ('DOLO strip of 15 EXP 08/2027','DOLO',None,15,'2027-08-31',None),
 ('??? strip of 15 EXP 08/2027',None,None,15,'2027-08-31',None),
 ('अस्पष्ट जानकारी',None,None,None,None,None),
 ('D0L0 650 strip of 15 EXP 08/2027',None,'650',15,'2027-08-31',None),
 ('DOLO 650 mg 100 ml EXP 08/2027','DOLO','650 mg',100,'2027-08-31',None),
 ('DOLO 650 mcg strip of 15 EXP 08/2027','DOLO','650 mcg',15,'2027-08-31',None),
 ('DOLO 650 iu strip of 15 EXP 08/2027','DOLO','650 iu',15,'2027-08-31',None),
 ('DOLO 650 g strip of 15 EXP 08/2027','DOLO','650 g',15,'2027-08-31',None),
 ('DOLO 650/500 mg strip of 15 EXP 08/2027','DOLO',None,15,'2027-08-31',None),
])
def test_thirty_handwritten_pack_texts(raw,brand,strength,units,expiry,batch):
    out=parse_pack_text(raw)
    assert {k:out[k] for k in ['brand','strength','units','expiry','batch']}==dict(brand=brand,strength=strength,units=units,expiry=expiry,batch=batch)

def test_actual_raw_example():assert verdict(EXAMPLE)=='ok'

def test_real_brand_beats_ocr_tolerance():
    assert distance(normalise_brand('SOLO'),normalise_brand('DOLO'))==1
    assert verdict(payload(brand='SOLO',strength='100'))=='brand_differs'
    assert verdict(payload(brand='CALPOL',strength='650'))=='brand_differs'

@pytest.mark.parametrize('observed',['D0L0','DOLQ','DQLO','DQXO'])
def test_ocr_brand_stays_tentative(observed):
    out=compare(payload(brand=observed))['lines'][0]
    assert out['verdict']=='likely_ok' and 'check the pack' in out['message']

def test_explicit_approved_substitute_is_tentative():
    p=payload(brand='CALPOL');p['options']['approvedSubstituteBrands']=['CALPOL']
    out=compare(p)['lines'][0]
    assert out['verdict']=='likely_ok' and 'Substitute you approved' in out['message']

def test_bad_strength_overrides_approval():
    p=payload(brand='CALPOL',strength='500');p['options']['approvedSubstituteBrands']=['CALPOL']
    assert verdict(p)=='strength_differs'

def test_decimal_strength_and_units():
    p=payload(brand='ALPRAX',strength='.5 mg');p['confirmed'][0].update(name='ALPRAX',strength='0.5 mg')
    assert verdict(p)=='ok'
    p['received'][0]['strength']='0.5 mcg'
    assert verdict(p)=='strength_differs'

@pytest.mark.parametrize('strength',[None,'999999999','650/500','x','NaN'])
def test_unknown_strength_is_not_ok(strength):assert verdict(payload(strength=strength))=='unreadable'

def test_expiry_all_findings_preserved():
    out=compare(payload(brand='CALPOL',strength='500',units=1,expiry='2020-01-31'))['lines'][0]
    assert out['verdict']=='expired' and out['severity']=='stop'
    assert {'expired','brand_differs','strength_differs','quantity_short'}<={f['code'] for f in out['findings']}

@pytest.mark.parametrize('today,expiry,wanted',[('2028-02-29','02/2028','expiry_soon'),('2028-03-01','02/2028','expired'),('2027-02-28','02/2027','expiry_soon'),('2026-10-24','2027-01-24','expiry_soon'),('2026-10-24','2027-01-25','ok')])
def test_expiry_boundaries(today,expiry,wanted):
    p=payload(expiry=expiry);p['options']['today']=today
    assert verdict(p)==wanted

def test_calendar_threshold_clips_month_end():
    assert add_months(date(2028,1,31),1)==date(2028,2,29)
    assert add_months(date(2027,1,31),1)==date(2027,2,28)
    assert parse_expiry('02/28')==date(2028,2,29)
    assert parse_expiry('02/99')==date(2099,2,28)

def test_split_packs_counted_and_one_expired_pack_blocks():
    p=payload(units=10);p['received'].append(copy.deepcopy(p['received'][0]))
    out=compare(p);assert out['lines'][0]['verdict']=='ok' and out['lines'][0]['receivedIndices']==[0,1]
    p['received'][1]['expiry']='2020-01-31';assert verdict(p)=='expired'

def test_missing_quantity_does_not_become_zero():assert verdict(payload(units=None))=='unreadable'

def test_volume_not_assumed_to_be_tablet_count():
    p=copy.deepcopy(EXAMPLE);p['received'][0]['rawText']='DOLO 650 mg 100 ml EXP 08/2027';p['confirmed'][0].update(qty=100,strength='650 mg')
    assert verdict(p)=='unreadable'
    p['confirmed'][0]['unitsKind']='ml';assert verdict(p)=='ok'

def test_conflicting_raw_and_typed_information_is_flagged():
    p=copy.deepcopy(EXAMPLE);p['received'][0]['strength']='500'
    out=compare(p)['lines'][0]
    assert out['verdict']=='strength_differs'
    assert any(f['detail']=='conflicting raw and structured strength' for f in out['findings'])
    p['received'][0].update(brand='CALPOL',strength='650')
    assert verdict(p)=='brand_differs'


def test_extra_missing_and_non_positional_matching():
    p=payload();p['confirmed'].append({'itemId':'az','name':'AZITHRAL','strength':'500','qty':6})
    p['received'].insert(0,{'brand':'AZITHRAL','strength':'500','units':6,'expiry':'2027-08-31'})
    out=compare(p);assert [l['verdict'] for l in out['lines']]==['ok','ok']
    assert out['lines'][0]['receivedIndices']==[1] and out['lines'][1]['receivedIndices']==[0]
    p['received']=[];assert [l['verdict'] for l in compare(p)['lines']]==['missing','missing']


def test_ambiguous_many_mismatches_are_not_assigned():
    p=payload();p['confirmed'].append({'itemId':'az','name':'AZITHRAL','strength':'500','qty':6})
    p['received']=[{'brand':'ALPRAX','strength':'.5','units':10,'expiry':'2027-08-31'},{'brand':'CALPOL','strength':'500','units':10,'expiry':'2027-08-31'}]
    out=compare(p)
    assert [l['verdict'] for l in out['lines']]==['missing','missing'] and len(out['extra'])==2


def test_h1_note_from_real_catalogue():
    _,schedules,_=load_catalogue()
    assert schedules['ALPRAX']['schedule']=='H1'
    p=payload(brand='ALPRAX',strength='.5');p['confirmed'][0].update(name='ALPRAX',strength='0.5')
    assert compare(p)['lines'][0]['note']=='Keep your original parchi and the bill for this medicine.'

@pytest.mark.parametrize('v,issue',[('strength_differs','wrong_item'),('brand_differs','wrong_item'),('expired','expired_or_damaged'),('missing','missing_item'),('quantity_short','missing_item')])
def test_problem_helper_adapter(v,issue):
    original={'lang':'en','seller':{'name':'Example','kind':'local_shop'}}
    result=to_problem_helper_input({'verdict':v},original)
    assert result['issue']==issue and 'issue' not in original
    assert to_problem_helper_input({'verdict':'ok'},original) is None

@pytest.mark.parametrize('value',[-1,1.5,True,'3',121])
def test_bad_threshold(value):
    p=payload();p['options']['minMonthsToExpiry']=value
    with pytest.raises(ValueError):compare(p)

def test_unknown_confirmed_brand_and_duplicate_ids():
    p=payload();p['confirmed'][0]['name']='NEWUNKNOWNBRAND';assert verdict(p)=='unreadable'
    p=payload();p['confirmed'].append(copy.deepcopy(p['confirmed'][0]))
    with pytest.raises(ValueError):compare(p)


def test_no_network_and_input_not_mutated(monkeypatch):
    import socket
    monkeypatch.setattr(socket,'socket',lambda *a,**k:pytest.fail('runtime network attempted'))
    p=payload();before=copy.deepcopy(p);compare(p);assert p==before


def test_conflicting_expiry_labels_stay_unresolved():
    p=copy.deepcopy(EXAMPLE);p['received'][0]['rawText']='DOLO 650 strip of 15 EXP 08/2027 EXP 01/2020'
    assert parse_pack_text(p['received'][0]['rawText'])['expiry'] is None
    assert verdict(p)=='unreadable'

def test_strength_unit_is_not_inferred_from_numeric_catalogue():
    assert verdict(payload(strength='650 g'))=='unreadable'
    assert verdict(payload(strength='650 mg'))=='unreadable'
    p=payload(strength='650 mg');p['confirmed'][0]['strength']='650 mg';assert verdict(p)=='ok'
    p=payload(strength='650 g');p['confirmed'][0]['strength']='650 mg';assert verdict(p)=='strength_differs'
