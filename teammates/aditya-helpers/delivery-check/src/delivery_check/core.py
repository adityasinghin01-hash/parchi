"""Offline delivery comparison. Unknown information remains unresolved."""
from __future__ import annotations
from functools import lru_cache
from pathlib import Path
from decimal import Decimal, InvalidOperation
from datetime import date
from collections import Counter
import calendar,json,re

DEFAULT_CATALOGUE=Path(__file__).resolve().parents[5]/'engine/catalogue'
MESSAGES={
 'ok':('Brand, strength, quantity and expiry match the checked fields.','जांचे गए ब्रांड, स्ट्रेंथ, संख्या और एक्सपायरी मेल खाते हैं।'),
 'likely_ok':('Looks like {brand}, please check the pack.','यह {brand} जैसा लगता है; कृपया पैक जांचें।'),
 'strength_differs':('The strength differs from your confirmed list; ask the seller to check.','स्ट्रेंथ आपकी पुष्टि की सूची से अलग है; विक्रेता से जांचने को कहें।'),
 'brand_differs':('This is not the brand on your parchi; ask the seller why.','यह आपकी पर्ची वाला ब्रांड नहीं है; विक्रेता से कारण पूछें।'),
 'quantity_short':('Fewer than ordered; ask the seller for the missing units.','ऑर्डर से कम सामान मिला है; विक्रेता से बाकी सामान मांगें।'),
 'expired':('Do not use; ask the seller to replace.','इस्तेमाल न करें; विक्रेता से बदलने को कहें।'),
 'expiry_soon':('Expiry is within your chosen threshold; check with the seller.','एक्सपायरी आपकी चुनी अवधि में है; विक्रेता से जांचें।'),
 'unreadable':('Some fields could not be checked; read the pack and enter the missing details.','कुछ जानकारी जांच नहीं सके; पैक पढ़कर छूटी जानकारी भरें।'),
 'missing':('This item has no matching received entry; check with the seller.','इस सामान की मिली हुई एंट्री नहीं है; विक्रेता से पूछें।')}
PRIORITY=['expired','brand_differs','strength_differs','unreadable','quantity_short','expiry_soon','likely_ok','ok']
SEVERITY={'expired':'stop','brand_differs':'stop','strength_differs':'stop','missing':'check','unreadable':'check','quantity_short':'check','expiry_soon':'check','likely_ok':'check','ok':'info'}


@lru_cache(maxsize=4)
def load_catalogue(folder=str(DEFAULT_CATALOGUE)):
    folder=Path(folder)
    strengths=json.loads((folder/'brand_strengths.json').read_text(encoding='utf-8'))
    schedules=json.loads((folder/'brand_schedule.json').read_text(encoding='utf-8'))
    version=json.loads((folder/'DATA_VERSION.json').read_text(encoding='utf-8'))
    return strengths,schedules,version


def normalise_brand(value):
    s=re.sub(r'[^A-Z0-9]','',str(value).upper())
    return s.replace('RN','M').translate(str.maketrans({'0':'O','1':'I','L':'I','5':'S'}))


def distance(a,b):
    if abs(len(a)-len(b))>2:return 3
    previous=list(range(len(b)+1))
    for i,c in enumerate(a,1):
        current=[i]
        for j,d in enumerate(b,1):current.append(min(current[-1]+1,previous[j]+1,previous[j-1]+(c!=d)))
        previous=current
    return previous[-1]


def _strength(value):
    if value is None or isinstance(value,bool):return None
    m=re.fullmatch(r'\s*(\d+(?:\.\d+)?|\.\d+)\s*(mg|mcg|g|ml|iu)?\s*',str(value),re.I)
    if not m:return None
    try:return Decimal(m[1]),(m[2] or '').lower()
    except InvalidOperation:return None


def _same_strength(a,b):
    aa,bb=_strength(a),_strength(b)
    if not aa or not bb:return False
    return aa[0]==bb[0] and (not aa[1] or not bb[1] or aa[1]==bb[1])


def parse_expiry(value):
    if not value or not isinstance(value,str):return None
    try:
        if re.fullmatch(r'\d{4}-\d{2}-\d{2}',value):return date.fromisoformat(value)
        m=re.fullmatch(r'(\d{1,2})[/-](\d{4}|\d{2})',value.strip())
        if m:
            month=int(m[1]);year=int(m[2]);year=year+2000 if len(m[2])==2 else year
        else:
            m=re.fullmatch(r'([A-Za-z]{3,9})[ -]+(\d{4}|\d{2})',value.strip())
            if not m:return None
            names={name.lower():i for i,name in enumerate(calendar.month_abbr) if i}
            if m[1][:3].lower() not in names:return None
            month=names[m[1][:3].lower()];year=int(m[2]);year=year+2000 if len(m[2])==2 else year
        if not 1<=month<=12 or not 1<=year<=9999:return None
        return date(year,month,calendar.monthrange(year,month)[1])
    except (ValueError,OverflowError):return None


def add_months(day,months):
    n=day.year*12+day.month-1+months;y,m=divmod(n,12)
    if not 1<=y<=9999:raise ValueError('expiry threshold is out of range')
    return date(y,m+1,min(day.day,calendar.monthrange(y,m+1)[1]))


def parse_pack_text(rawText, catalogue_dir=None):
    """Parse labelled expiry/batch and leading brand; ambiguous fields stay null."""
    if not isinstance(rawText,str):raise ValueError('rawText must be a string')
    strengths,_,_=load_catalogue(str(catalogue_dir or DEFAULT_CATALOGUE))
    text=rawText.strip();lead=re.match(r'(?:Brand\s*[:=]\s*)?([A-Za-z0-9][A-Za-z0-9-]*)',text,re.I)
    candidate=lead[1].upper() if lead else None
    brand=candidate if candidate in strengths else None
    # Keep the observed token for comparison; do not silently repair it to a real brand.
    rest=text[lead.end():] if lead else ''
    strength_match=re.match(r'\s*[-:]?\s*(\d+(?:\.\d+)?|\.\d+)\s*(mg|mcg|g|ml|iu)?\b',rest,re.I)
    strength=None
    if strength_match:
        strength=strength_match[1]+((' '+strength_match[2].lower()) if strength_match[2] else '')
        if rest[strength_match.end():].lstrip().startswith(('/', '+')):strength=None
    # Do not invent units from a bare number or a strength suffix.
    quantity_text=text[(lead.end()+strength_match.end()) if lead and strength_match else (lead.end() if lead else 0):]
    units_match=re.search(r'\bstrip\s+of\s+(\d+)\b|\b(\d+)\s*(?:tablets?|tabs?|caps(?:ules?)?)\b|\b(\d+(?:\.\d+)?)\s*ml\b',quantity_text,re.I)
    units=None
    if units_match:
        value=next(v for v in units_match.groups() if v is not None)
        units=float(value) if '.' in value else int(value)
    expiry_match=re.search(r'\b(?:EXP(?:IRY)?\.?)\s*[:.-]?\s*(\d{1,2}[/-](?:\d{4}|\d{2})\b|[A-Za-z]{3,9}[ -]+(?:\d{4}|\d{2})\b)',text,re.I)
    expiry=parse_expiry(expiry_match[1]) if expiry_match else None
    all_expiry=re.findall(r'\b(?:EXP(?:IRY)?\.?)\s*[:.-]?\s*(\d{1,2}[/-](?:\d{4}|\d{2})\b|[A-Za-z]{3,9}[ -]+(?:\d{4}|\d{2})\b)',text,re.I)
    if len({parse_expiry(v) for v in all_expiry})>1:expiry=None
    batch=re.search(r'\b(?:B\.?\s*No\.?|Batch(?:\s*No\.?)?)\s*[:.-]?\s*([A-Za-z0-9/-]+)',text,re.I)
    return {'brand':brand,'strength':strength,'units':units,'expiry':expiry.isoformat() if expiry else None,'batch':batch[1] if batch else None,'brandCandidate':candidate,'unitsKind':'ml' if units_match and units_match[3] else ('count' if units_match else None)}


def _brand_relation(observed,expected,strengths,approved):
    if not isinstance(observed,str) or not observed.strip():return 'unreadable'
    observed=observed.strip().upper();expected=str(expected).strip().upper()
    if expected not in strengths:return 'unreadable'
    if observed==expected:return 'ok'
    if observed in approved:return 'approved'
    if observed in strengths:return 'brand_differs' # Real brand identity precedes OCR tolerance.
    if not re.fullmatch(r'[A-Z0-9-]+',observed):return 'unreadable'
    if distance(normalise_brand(observed),normalise_brand(expected))<=2:return 'likely_ok'
    return 'brand_differs'


def _received(entry,catalogue_dir):
    if not isinstance(entry,dict):raise ValueError('received entries must be objects')
    parsed=parse_pack_text(entry.get('rawText','') or '',catalogue_dir)
    parsed['conflicts']=[]
    for field in ('brand','strength','units','expiry','batch'):
        if entry.get(field) is not None:
            before=parsed[field];after=entry[field]
            equal=(_same_strength(before,after) if field=='strength' else parse_expiry(before)==parse_expiry(after) if field=='expiry' else (str(before)==str(after) or (isinstance(before,(int,float)) and isinstance(after,(int,float)) and before==after)) if field=='units' else str(before).casefold()==str(after).casefold())
            if before is not None and not equal:parsed['conflicts'].append(field)
            parsed[field]=after
    if entry.get('brand') is not None:parsed['brandCandidate']=entry['brand']
    if entry.get('unitsKind') is not None:parsed['unitsKind']=entry['unitsKind']
    parsed['itemId']=entry.get('itemId')
    return parsed


def compare(payload,catalogue_dir=None):
    if not isinstance(payload,dict):raise ValueError('input must be an object')
    confirmed=payload.get('confirmed',[]);received=payload.get('received',[]);options=payload.get('options',{})
    if not isinstance(confirmed,list) or not isinstance(received,list) or not isinstance(options,dict):raise ValueError('confirmed/received must be arrays and options an object')
    try:today=date.fromisoformat(options['today'])
    except (ValueError,TypeError,KeyError) as exc:raise ValueError('options.today must be an ISO date') from exc
    months=options.get('minMonthsToExpiry',3)
    if type(months) is not int or not 0<=months<=120:raise ValueError('minMonthsToExpiry must be an integer from 0 to 120')
    threshold=add_months(today,months)
    approved=options.get('approvedSubstituteBrands',[])
    if not isinstance(approved,list) or any(not isinstance(x,str) for x in approved):raise ValueError('approvedSubstituteBrands must be a string array')
    approved={x.upper().strip() for x in approved}
    strengths,schedules,version=load_catalogue(str(catalogue_dir or DEFAULT_CATALOGUE))
    ids=[]
    for item in confirmed:
        if not isinstance(item,dict) or not isinstance(item.get('itemId'),str) or not item['itemId']:raise ValueError('confirmed itemId must be a nonempty string')
        if item['itemId'] in ids:raise ValueError('duplicate itemId')
        ids.append(item['itemId'])
        qty=item.get('qty')
        if not isinstance(qty,(int,float)) or isinstance(qty,bool) or qty<=0 or not Decimal(str(qty)).is_finite():raise ValueError('confirmed qty must be positive and finite')
    packs=[_received(r,catalogue_dir) for r in received]
    allocations={i:[] for i in range(len(confirmed))};used=set()
    # Explicit identity can associate a mismatch without guessing which line it belongs to.
    for j,p in enumerate(packs):
        if p['itemId'] in ids:allocations[ids.index(p['itemId'])].append(j);used.add(j)
    # Exact brand matching first, then an unknown token close to a single confirmed brand.
    for j,p in enumerate(packs):
        if j in used:continue
        observed=p['brand'] or p['brandCandidate']
        matches=[i for i,c in enumerate(confirmed) if _brand_relation(observed,c.get('name',''),strengths,approved)=='ok']
        if not matches:
            matches=[i for i,c in enumerate(confirmed) if _brand_relation(observed,c.get('name',''),strengths,approved) in {'likely_ok','approved'}]
        if len(matches)>1:
            exact_strength=[i for i in matches if any(_same_strength(p['strength'],s) for s in _expected_strengths(confirmed[i]))]
            if exact_strength:matches=exact_strength
        if len(matches)==1:
            allocations[matches[0]].append(j);used.add(j)
        elif matches:
            free=[i for i in matches if not allocations[i]]
            if free:allocations[free[0]].append(j);used.add(j)
    left_items=[i for i in allocations if not allocations[i]];left_packs=[j for j in range(len(packs)) if j not in used]
    # A single unmatched pair can be shown as a mismatch; multiple unmatched pairs stay unresolved.
    if len(left_items)==len(left_packs)==1:
        allocations[left_items[0]].append(left_packs[0]);used.add(left_packs[0])
    lines=[]
    for i,c in enumerate(confirmed):
        indices=allocations[i];findings=[];expected=str(c.get('name','')).upper();expected_strengths=_expected_strengths(c)
        def add(code,detail=None):
            if not any(f['code']==code and f.get('detail')==detail for f in findings):
                en,hi=MESSAGES[code];findings.append({'code':code,'message':en.format(brand=c.get('name','')),'messageHi':hi.format(brand=c.get('name','')),'detail':detail})
        if not indices:add('missing')
        else:
            quantities=[];quantity_unknown=False
            for j in indices:
                p=packs[j];observed=p['brand'] or p['brandCandidate']
                for field in p['conflicts']:add('unreadable','conflicting raw and structured '+field)
                relation=_brand_relation(observed,expected,strengths,approved)
                if relation=='approved':
                    findings.append({'code':'likely_ok','message':'Substitute you approved; please check the pack.','messageHi':'आपकी मंज़ूरी वाला विकल्प; कृपया पैक जांचें।','detail':'approved substitute'})
                elif relation!='ok':add(relation,'brand')
                if expected not in strengths or not expected_strengths or any(_strength(s) is None for s in expected_strengths):add('unreadable','confirmed brand or strength')
                observed_brand=str(observed).upper() if observed else ''
                validation_brand=observed_brand if observed_brand in strengths else expected if relation=='likely_ok' else None
                valid_strengths=strengths.get(validation_brand,[]) if validation_brand else []
                actual=_strength(p['strength'])
                if actual is None or not valid_strengths or not any(_strength(v) and _strength(v)[0]==actual[0] for v in valid_strengths):add('unreadable','check the strength on the pack')
                elif not any(_same_strength(p['strength'],s) for s in expected_strengths):add('strength_differs','strength')
                elif actual and actual[1] and all(_strength(s) and not _strength(s)[1] for s in expected_strengths):add('unreadable','confirmed strength unit is missing')
                quantity=p['units']
                if not isinstance(quantity,(int,float)) or isinstance(quantity,bool) or quantity<0 or not Decimal(str(quantity)).is_finite():quantity_unknown=True
                elif p.get('unitsKind') and c.get('unitsKind','count')!=p['unitsKind']:quantity_unknown=True
                else:quantities.append(Decimal(str(quantity)))
                expiry=parse_expiry(p['expiry'])
                if expiry is None:add('unreadable','expiry')
                elif expiry<today:add('expired','expiry')
                elif expiry<=threshold:add('expiry_soon','expiry')
            if quantity_unknown:add('unreadable','quantity')
            elif sum(quantities)<Decimal(str(c['qty'])):add('quantity_short','quantity')
        if not findings:add('ok')
        codes={f['code'] for f in findings}
        verdict='missing' if not indices else next(v for v in PRIORITY if v in codes)
        primary=next(f for f in findings if f['code']==verdict)
        line={'itemId':c['itemId'],'verdict':verdict,'message':primary['message'],'messageHi':primary['messageHi'],'severity':SEVERITY[verdict],'findings':findings,'receivedIndices':indices}
        schedule=schedules.get(expected,{})
        if isinstance(schedule,dict) and schedule.get('schedule') in {'H1','X'}:
            line['note']='Keep your original parchi and the bill for this medicine.'
            line['noteHi']='इस दवा के लिए अपनी मूल पर्ची और बिल संभालकर रखें।'
        lines.append(line)
    extra=[{'receivedIndex':j,'brand':p['brand'] or p['brandCandidate'],'message':'Not matched to the confirmed list; check with the seller.','messageHi':'पुष्टि की सूची से मेल नहीं मिला; विक्रेता से जांचें।'} for j,p in enumerate(packs) if j not in used]
    counts=dict(Counter(l['verdict'] for l in lines));checks=sum(l['verdict']!='ok' for l in lines)+len(extra)
    summary={'counts':counts,'extraCount':len(extra),'sentence':f'{len(lines)} confirmed lines checked; {checks} entries need checking.','nextStep':'Check flagged fields against the pack and ask the seller about differences.' if checks else 'Keep the confirmed list and bill.'}
    return {'lines':lines,'extra':extra,'summary':summary,'notes':[f'ASSUMPTION: near-expiry means within {months} calendar months; you can change this threshold.','Two-digit expiry years are interpreted as 2000–2099.','Hindi messages are drafts; native review pending.','Typed or reader text only; no photo validation performed.'],'dataVersion':version.get('build_date')}


def _expected_strengths(item):
    value=item.get('strength')
    return value if isinstance(value,list) else [value] if value is not None else []


def to_problem_helper_input(verdict_line,order_info):
    mapping={'strength_differs':'wrong_item','brand_differs':'wrong_item','expired':'expired_or_damaged','missing':'missing_item','quantity_short':'missing_item'}
    code=verdict_line.get('verdict')
    if code not in mapping:return None
    payload=dict(order_info);payload['issue']=mapping[code]
    return payload
