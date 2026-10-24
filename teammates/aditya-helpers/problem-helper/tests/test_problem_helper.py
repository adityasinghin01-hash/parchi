
import copy
import itertools
import json
import re
from datetime import date,timedelta
from pathlib import Path
import pytest
from problem_helper import generate,load_contacts,parse_contacts
from problem_helper.core import DATA

EXAMPLE=json.loads((DATA.parent/'example.json').read_text(encoding='utf-8'))
ISSUES=['not_delivered','late','cancelled_by_seller','wrong_item','missing_item','expired_or_damaged','refund_pending','overcharged','no_support_reply','lab_sample_issue','lab_report_late']
KINDS=['online_pharmacy','quick_commerce','lab','local_shop']
BANNED=re.compile(r'\b(sue|court|lawyer|police|threat|compensation|guarantee)\b',re.I)

def case(**kwargs):
    p=copy.deepcopy(EXAMPLE);p.update(kwargs);return p

@pytest.mark.parametrize('issue,lang,kind',list(list(itertools.product(ISSUES,['en','hi'],KINDS))))
def test_all_issue_language_seller_cases(issue,lang,kind):
    p=case(issue=issue,lang=lang,seller={'name':'Tata 1mg','kind':kind})
    out=generate(p); text=json.dumps(out,ensure_ascii=False)
    assert out['message']['lang']==lang
    assert 'EXAMPLE-001' in out['message']['subject']
    assert '₹2696.77' in out['message']['body']
    assert not re.search(r'\{[^{}]+\}',out['message']['body'])
    assert not BANNED.search(text)
    assert out['ladder'][0]['level']==1 and out['ladder'][0]['when']=='now'
    assert max(s['level'] for s in out['ladder'])==3
    assert 'check on the official site' in text
    assert 'SECONDARY SOURCES ONLY' in text
    if lang=='hi': assert re.search('[\u0900-\u097f]',out['message']['body'])
    if kind=='local_shop':
        assert [s['level'] for s in out['ladder']]==[1,3]
        assert out['followUps']==[]
        assert not re.search(r'48|30 days|1 month',text)

@pytest.mark.parametrize('row',load_contacts(),ids=lambda r:r['company'])
def test_contact_parser_every_row(row):
    for field,parsed in [('support','supportContacts'),('grievance','grievanceContacts')]:
        assert len(row[parsed])==row[field].count('@')
        for c in row[parsed]:
            assert c['value'] in row[field] and c['sourceUrl'] in row[field]
            assert c['dateSeen']==row['date_seen']

def test_contact_counts_and_missing_parser():
    rows=load_contacts()
    assert len(rows)==24
    assert sum(bool(r['grievanceContacts']) for r in rows)==15
    assert parse_contacts('NOT FOUND','2026-10-23')==[]
    assert parse_contacts('nobody@example.com without source','2026-10-23')==[]
    assert parse_contacts('', '2026-10-23')==[]

def test_known_contacts_provenance():
    out=generate(EXAMPLE)
    assert out['ladder'][0]['contact']=={'value':'care@1mg.com','sourceUrl':'https://www.1mg.com/aboutUs','dateSeen':'2026-10-23'}
    assert out['ladder'][1]['contact']['value']=='grievance-officer@1mg.com'
    assert out['ladder'][2]['contact']['value']=='1915'
    assert '8800001915' in out['ladder'][2]['how']

def test_unknown_company_does_not_guess():
    out=generate(case(seller={'name':'Imaginary Seller','kind':'online_pharmacy'}))
    assert out['ladder'][0]['contact'] is None
    assert [s['level'] for s in out['ladder']]==[1,3]
    assert 'we could not find a contact for this company' in out['notes']
    assert out['ladder'][-1]['when']=='now'

def test_missing_grievance_keeps_real_support():
    out=generate(case(seller={'name':'Medkart','kind':'online_pharmacy'}))
    assert out['ladder'][0]['contact']['value']=='info@medkart.in'
    assert [s['level'] for s in out['ladder']]==[1,3]

@pytest.mark.parametrize('sent,ack,resolution',[('2026-12-31','2027-01-02','2027-01-30'),('2028-02-28','2028-03-01','2028-03-29'),('2026-01-31','2026-02-02','2026-03-02')])
def test_actual_sent_date_boundaries(sent,ack,resolution):
    p=case(today=sent,events={'grievanceSentOn':sent})
    p['order']['placedOn']=sent
    out=generate(p)
    assert [x['dueOn'] for x in out['followUps']]==[ack,resolution]
    assert all(x['basis']=='sent' for x in out['followUps'])

@pytest.mark.parametrize('support,today,expected',[('2026-10-29','2026-10-30','2026-10-31'),('2026-10-20','2026-10-30','2026-10-30')])
def test_later_of_support_plus_two_and_today(support,today,expected):
    out=generate(case(today=today,events={'supportContactedOn':support}))
    assert out['ladder'][1]['when']==expected
    assert out['followUps'][0]['dueOn']==(date.fromisoformat(expected)+timedelta(days=2)).isoformat()
    assert out['ladder'][2]['when']==out['followUps'][0]['dueOn']
    assert all(f['basis']=='planned' for f in out['followUps'])
    assert any('ASSUMPTION' in n for n in out['notes'])

def test_overdue_ack_offers_helpline_now_without_claiming_no_reply():
    out=generate(case(events={'grievanceSentOn':'2026-10-23'}))
    assert out['ladder'][2]['when']=='2026-10-30'
    assert out['ladder'][2]['why'].startswith('If there is no reply')

def test_sandbox_has_no_contacts_or_followups():
    p=case();p['order']['isTestOrder']=True
    out=generate(p)
    assert out['message']['subject'].startswith('Test order')
    assert not out['ladder'] and not out['followUps']
    assert '@' not in json.dumps(out)

@pytest.mark.parametrize('issue',['wrong_item','expired_or_damaged'])
def test_precaution_not_reviewed(issue):
    out=generate(case(issue=issue))
    assert out['precautions']==[{'text':'Do not use this medicine until the seller confirms.','reviewed':False}]

def test_only_supplied_facts_appear():
    p=case(events={});p['order']={}
    out=generate(p)
    assert '₹' not in out['message']['body']
    assert 'Order ID' not in out['message']['body']
    assert 'Placed on' not in out['message']['body']
    assert '2026-' not in out['message']['body']

def test_refund_does_not_assume_entire_order_is_disputed():
    out=generate(EXAMPLE)
    assert 'amount due for refund' in out['message']['body']
    assert 'original payment method' in out['message']['body']
    assert 'refund ₹2696.77' not in out['message']['body']

@pytest.mark.parametrize('patch',[{'lang':'xx'},{'issue':'unknown'},{'today':'not-a-date'},{'events':{'supportContactedOn':'2027-01-01'}},{'seller':{'name':'x','kind':'unknown'}}])
def test_invalid_inputs(patch):
    with pytest.raises(ValueError):generate(case(**patch))

@pytest.mark.parametrize('amount',[-1,1.1,True,'10'])
def test_bad_amount(amount):
    p=case();p['order']['amountPaise']=amount
    with pytest.raises(ValueError):generate(p)

def test_no_runtime_network(monkeypatch):
    import socket
    monkeypatch.setattr(socket,'socket',lambda *a,**k:pytest.fail('runtime network attempted'))
    generate(EXAMPLE)

@pytest.mark.parametrize('file',sorted((Path(__file__).parent/'golden').glob('*.json')),ids=lambda p:p.stem)
def test_golden(file):
    saved=json.loads(file.read_text(encoding='utf-8'))
    assert generate(saved['input'])==saved['output']

@pytest.mark.parametrize('field',['seller','order','events'])
def test_wrong_object_shape(field):
    with pytest.raises(ValueError):generate(case(**{field:[]}))

@pytest.mark.parametrize('field',['seller','order','events'])
def test_wrong_object_shape(field):
    with pytest.raises(ValueError):generate(case(**{field:[]}))


def test_demo_http_get_and_generate():
    import importlib.util, threading, urllib.request, urllib.error
    from http.server import HTTPServer
    spec=importlib.util.spec_from_file_location('problem_demo',DATA.parent/'demo/serve.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    with HTTPServer(('127.0.0.1',0),mod.Handler) as server:
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        url=f'http://127.0.0.1:{server.server_port}'
        try:
            with urllib.request.urlopen(url+'/') as response:
                assert 'Something went wrong?' in response.read().decode()
            with urllib.request.urlopen(url+'/companies') as response:
                assert len(json.load(response))==24
            req=urllib.request.Request(url+'/generate',data=json.dumps(EXAMPLE).encode(),headers={'Content-Type':'application/json'})
            with urllib.request.urlopen(req) as response:
                assert json.load(response)==generate(EXAMPLE)
            bad=urllib.request.Request(url+'/generate',data=b'{}',headers={'Origin':'https://example.com'})
            with pytest.raises(urllib.error.HTTPError) as error:urllib.request.urlopen(bad)
            assert error.value.code==403
            missing=urllib.request.Request(url+'/generate',data=b'{}')
            with pytest.raises(urllib.error.HTTPError) as error:urllib.request.urlopen(missing)
            assert error.value.code==400
        finally:
            server.shutdown();thread.join()
