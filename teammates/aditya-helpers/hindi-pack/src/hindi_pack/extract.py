"""Conservative Swift lexical extractor; does not claim to be a Swift type checker."""
from __future__ import annotations
import argparse,csv,json,re
from dataclasses import dataclass
from pathlib import Path

PATTERNS=set("Text Label Button NavigationLink Section Toggle Picker Stepper TextField Menu ProgressView ContentUnavailableView navigationTitle accessibilityLabel accessibilityHint alert confirmationDialog help".split())
SKIP_CALLS={'accessibilityIdentifier','Image','UserDefaults','URL','URLRequest','systemImage','systemName'}
UI_WORDS={'home','care','done','save','cancel','continue','back','next','open','settings','history','track','plan','confirm','remove','delete','share','help','unknown','all','today','retry','search','no','yes','test','report','price','order','stop'}
CLEAR_DATA={'dolo','augmentin','azithral','telma','glycomet','pan','montair','tata 1mg','pharmeasy','netmeds','blinkit','zepto','apollo pharmacy','truemeds','swiggy instamart','bigbasket','flipkart minutes','amazon pharmacy','medplus','medkart','wellness forever','dr lal pathlabs','thyrocare','redcliffe labs','healthians','metropolis','apollo diagnostics','max lab','orange health','agilus (srl)','apollo','redcliffe'}

@dataclass
class Token:
    kind:str
    value:str
    start:int
    end:int
    content:str=''
    hashes:int=0


def _string(source,start):
    m=re.match(r'(#+)?("""|")',source[start:])
    if not m:return None
    hashes=len(m.group(1) or '');quote=m.group(2);opener=m.group(0)
    end_quote=quote+'#'*hashes; i=start+len(opener);begin=i
    escape='\\'+'#'*hashes
    while i<len(source):
        if source.startswith(escape+'(',i):
            depth=1;i+=len(escape)+1
            while i<len(source) and depth:
                nested=_string(source,i)
                if nested:i=nested.end;continue
                if source[i]=='(':depth+=1
                elif source[i]==')':depth-=1
                i+=1
            continue
        if source.startswith(escape,i):
            i+=len(escape)+1;continue
        if source.startswith(end_quote,i):
            return Token('string',source[start:i+len(end_quote)],start,i+len(end_quote),source[begin:i],hashes)
        i+=1
    return Token('invalid',source[start:],start,len(source))


def lex(source):
    tokens=[];i=0
    while i<len(source):
        if source[i].isspace():i+=1;continue
        if source.startswith('//',i):
            j=source.find('\n',i);i=len(source) if j<0 else j+1;continue
        if source.startswith('/*',i):
            depth=1;i+=2
            while i<len(source) and depth:
                if source.startswith('/*',i):depth+=1;i+=2
                elif source.startswith('*/',i):depth-=1;i+=2
                else:i+=1
            continue
        t=_string(source,i)
        if t:tokens.append(t);i=t.end;continue
        m=re.match(r'[A-Za-z_$][\w$]*',source[i:])
        if m:
            tokens.append(Token('id',m.group(),i,i+len(m.group())));i+=len(m.group());continue
        tokens.append(Token('symbol',source[i],i,i+1));i+=1
    return tokens


def debug_lines(source):
    """Exclude DEBUG arms while retaining their production #else arms."""
    excluded=set();stack=[]
    for line_no,line in enumerate(source.splitlines(),1):
        s=line.strip()
        if s.startswith('#if '):
            condition=s[4:];is_debug=bool(re.search(r'\bDEBUG\b',condition)) and not bool(re.search(r'!\s*DEBUG',condition))
            stack.append([is_debug,is_debug]);excluded.add(line_no)
        elif s.startswith('#elseif ') and stack:
            stack[-1][0]=bool(re.search(r'\bDEBUG\b',s)) and not bool(re.search(r'!\s*DEBUG',s));excluded.add(line_no)
        elif s=='#else' and stack:
            stack[-1][0]=not stack[-1][1] if stack[-1][1] else False;excluded.add(line_no)
        elif s=='#endif' and stack:
            stack.pop();excluded.add(line_no)
        elif any(s[0] for s in stack):excluded.add(line_no)
    return excluded


def key_for(token):
    content=token.content;escape='\\'+'#'*token.hashes;out=[];i=0;manual=False
    while i<len(content):
        if content.startswith(escape+'(',i):
            begin=i+len(escape)+1;j=begin;depth=1
            while j<len(content) and depth:
                nested=_string(content,j)
                if nested:j=nested.end;continue
                if content[j]=='(':depth+=1
                elif content[j]==')':depth-=1
                j+=1
            expression=content[begin:j-1].strip()
            integer=bool(re.fullmatch(r'\d+|(?:\w+\.)*(?:count|qty|quantity|index|totalCount|itemCount|days|minutes|hours|remaining)',expression) or re.search(r'\bInt\(|\.count(?:\s*[+\-]\s*\w+(?:\.count)?)?$',expression))
            stringy=bool(re.search(r'\bString\(|\b(?:name|title|brand|strength|message)\b|rupees\(|\.joined\(|sellerName\(|itemName\(',expression))
            out.append('%lld' if integer else '%@')
            if not integer and not stringy:manual=True
            i=j;continue
        if content.startswith(escape,i):
            j=i+len(escape)
            if j<len(content):
                c=content[j];out.append({'n':'\n','t':'\t','r':'\r','"':'"','\\':'\\','0':'\0'}.get(c,c));i=j+1;continue
        out.append(content[i]);i+=1
    value=''.join(out)
    if token.value.lstrip('#').startswith('"""'):
        lines=value.splitlines()
        if lines and not lines[0].strip():lines=lines[1:]
        if lines and not lines[-1].strip():lines=lines[:-1]
        nonempty=[len(s)-len(s.lstrip()) for s in lines if s.strip()]
        indent=min(nonempty,default=0);value='\n'.join(s[indent:] for s in lines)
    # Literal percent signs must be escaped in interpolation format keys.
    if '%@' in value or '%lld' in value:
        value=re.sub(r'%(?!@|lld|\d+\$[@d])','%%',value)
    return value,manual


def is_data(text):
    stripped=text.strip()
    without_placeholders=re.sub(r'%(?:\d+\$)?(?:lld|@|d|f|s)', '', stripped)
    if not re.search('[A-Za-z]',without_placeholders):return True
    if re.fullmatch(r'(?:[yMdEHhmsSaZz]+[ /:,.\-]*)+',stripped) and len(stripped)>2:return True
    return not bool(re.search('[A-Za-z]',stripped)) or bool(re.match(r'(?:https?://|[\w.-]+://)',stripped)) or stripped.casefold() in CLEAR_DATA or bool(re.fullmatch(r'[₹\d\W]+',stripped)) or bool(re.fullmatch(r'[A-Z][A-Za-z-]+\s+\d+(?:\.\d+)?\s*(?:mg|mcg|ml|g|IU)?',stripped))


def extract(root: str|Path):
    root=Path(root)
    if not root.is_dir():raise ValueError(f'Swift source folder does not exist: {root}')
    entries={};skipped=[];manual=[];not_auto=[];files=sorted(root.rglob('*.swift'))
    for path in files:
        relative=path.relative_to(root).as_posix()
        if any('test' in p.casefold() for p in Path(relative).parts) or relative.endswith('Design/ThemePreview.swift'):
            skipped.append({'where':relative,'reason':'test or theme preview file'});continue
        source=path.read_text(encoding='utf-8-sig');tokens=lex(source);debug=debug_lines(source);used=set();excluded=set()
        line=lambda t:source.count('\n',0,t.start)+1
        where=lambda t:f'{relative}:{line(t)}'
        # Mark forbidden call arguments so the fallback report cannot leak symbol/identifier/data literals.
        for n,t in enumerate(tokens):
            if t.kind=='id' and t.value in SKIP_CALLS and n+1<len(tokens) and tokens[n+1].value=='(':
                depth=1;k=n+2
                while k<len(tokens) and depth:
                    if tokens[k].value=='(':depth+=1
                    if tokens[k].value==')':depth-=1
                    if tokens[k].kind=='string':excluded.add(k)
                    k+=1
            if t.kind=='id' and t.value in {'systemImage','systemName','forKey','key','jsonKey','format'} and n+2<len(tokens) and tokens[n+1].value==':' and tokens[n+2].kind=='string':excluded.add(n+2)
        for n,t in enumerate(tokens):
            if t.kind!='id' or t.value not in PATTERNS or n+1>=len(tokens) or tokens[n+1].value!='(':continue
            if line(t) in debug:continue
            start=n+2
            if start>=len(tokens):continue
            if tokens[start].value=='verbatim':
                if start+2<len(tokens):excluded.add(start+2)
                continue
            # The first top-level argument only; nested string expressions are manual.
            depth=0;end=start
            while end<len(tokens):
                v=tokens[end].value
                if v in ('(', '[','{'):depth+=1
                if v in (')',']','}'):
                    if depth==0:break
                    depth-=1
                if v==',' and depth==0:break
                end+=1
            candidates=[i for i in range(start,end) if tokens[i].kind=='string' and i not in excluded]
            literal_first=start<end and tokens[start].kind=='string' and end==start+1
            if not literal_first:
                expression=source[tokens[start].start:tokens[end-1].end] if end>start else ''
                # String-valued expressions need a source change, even when no literal occurs here.
                if expression and ':' not in expression[:20]:
                    not_auto.append({'where':where(t),'expression':expression[:200],'fix':'Wrap user-facing String values with String(localized:) or use LocalizedStringKey after review.'})
            for i in candidates:
                used.add(i);tok=tokens[i];english,needs_manual=key_for(tok)
                if line(tok) in debug or is_data(english):
                    skipped.append({'where':where(tok),'reason':'debug/data/non-English'});continue
                manual_needed=needs_manual or not literal_first
                record=entries.setdefault(english,{'key':english,'english':english,'locations':[],'needs_manual':False})
                record['locations'].append(where(tok));record['needs_manual']|=manual_needed
                if manual_needed:manual.append({'where':where(tok),'key':english,'reason':'interpolation type or nonliteral expression requires review'})
        for n,t in enumerate(tokens):
            if t.kind!='string' or n in used:continue
            text,_=key_for(t)
            if n in excluded or line(t) in debug or is_data(text) or (n+1<len(tokens) and tokens[n+1].value==':'):
                skipped.append({'where':where(t),'reason':'excluded argument/debug/data'});continue
            # Conservative candidates: assignments, computed returns, concatenation, ternaries.
            before=source[max(0,t.start-160):t.start]
            if re.search(r'(?:=|return|\?|:|\+)\s*$',before):
                not_auto.append({'where':where(t),'expression':text[:200],'fix':'Confirm this is UI text; use String(localized:) or LocalizedStringKey at its source.'})
            else:skipped.append({'where':where(t),'reason':'not a supported UI literal'})
    return {'entries':[entries[k] for k in sorted(entries)],'skipped':skipped,'needs_manual':manual,'not_auto':not_auto,'files':len(files)}


def placeholders(text):
    return re.findall(r'%(?:\d+\$)?(?:lld|@|d|f|s)',re.sub(r'%%','',text))


def validate_rows(rows):
    errors=[]
    for row in rows:
        key=row['key'];hi=row.get('hindi','')
        if row.get('status') not in {'draft','reviewed'}:errors.append(f'{key}: invalid status')
        if row.get('status')=='reviewed' and not hi.strip():errors.append(f'{key}: reviewed translation is empty')
        if hi and placeholders(row.get('english',key))!=placeholders(hi):errors.append(f'{key}: placeholder parity differs')
    return errors


def build_catalog(rows,include_drafts=False):
    rows=list(rows);errors=validate_rows(rows)
    if errors:raise ValueError('\n'.join(errors))
    strings={}
    for row in rows:
        if not row.get('hindi','').strip():continue
        status=row.get('status','draft')
        if status!='reviewed' and not include_drafts:continue
        strings[row['key']]={'localizations':{'hi':{'stringUnit':{'state':'translated' if status=='reviewed' else 'needs_review','value':row['hindi']}}}}
    return {'sourceLanguage':'en','strings':strings,'version':'1.0'}


def glossary_violations(rows,glossary):
    violations=[]
    for row in rows:
        remaining=row['english']
        for en,hi in sorted(glossary.items(),key=lambda pair:len(pair[0]),reverse=True):
            pattern=r'(?<!\w)'+re.escape(en)+r'(?!\w)'
            if re.search(pattern,remaining,re.I):
                if hi not in row.get('hindi',''):
                    violations.append(f"{row['key']}: expected glossary term {hi} for {en}")
                remaining=re.sub(pattern,'',remaining,flags=re.I)
    return violations


def write_outputs(result,out,translations=None,include_drafts=False,glossary=None,existing_rows=None):
    out=Path(out);out.mkdir(parents=True,exist_ok=True);translations=translations or {};rows=[]
    previous={r['key']:r for r in (existing_rows or [])}
    for e in result['entries']:
        old=previous.get(e['key'],{});translation=old.get('hindi',translations.get(e['key'],''))
        # Do not silently upgrade drafts or invent a review.
        row={'key':e['key'],'english':e['english'],'hindi':translation,'status':old.get('status','draft'),
             'screen_hint':'; '.join(e['locations']),'max_ratio_note':f"{len(translation)/max(1,len(e['english'])):.2f}x"}
        rows.append(row)
    errors=validate_rows(rows)
    if errors:raise ValueError('\n'.join(errors))
    with (out/'translation-sheet.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=['key','english','hindi','status','screen_hint','max_ratio_note']);writer.writeheader();writer.writerows(rows)
    catalog=build_catalog(rows,include_drafts)
    (out/'Localizable.xcstrings').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# Strings requiring a source change','','Conservative candidates; data/configuration may be false positives. These are not automatically localized by a catalog.']
    for entry in result['not_auto']:
        expression=entry['expression'].replace('\n',' ')
        lines.append(f"- {entry['where']}: `{expression}` — {entry['fix']}")
    (out/'not-auto-localizable.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    violations=glossary_violations(rows,glossary or {})
    ratios=sorted(rows,key=lambda r:len(r['hindi'])/max(1,len(r['english'])),reverse=True)[:20]
    counts={'files':result['files'],'found':len(rows),'skipped':len(result['skipped']),'needs_manual':len(result['needs_manual']),'not_auto_localizable':len(result['not_auto']),'drafts':sum(r['status']=='draft' for r in rows),'translated_nonempty':sum(bool(r['hindi'].strip()) for r in rows),'catalog_entries':len(catalog['strings']),'glossary_violations':len(violations)}
    report=['# Hindi extraction report','','Drafts require a native speaker. Lexical extraction is not a Swift compiler; review manual candidates and rerun against the final frontend.','', '```json',json.dumps(counts,indent=2),'```','','## Longest Hindi/English character ratios (layout risk)']
    report += [f"- {r['max_ratio_note']}: {r['key']}" for r in ratios]
    report += ['','## Glossary violations']+(violations or ['None in supplied translations.'])
    report += ['','## Needs manual interpolation/expression review']+[f"- {r['where']}: {r['key']} — {r['reason']}" for r in result['needs_manual']]
    (out/'report.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
    (out/'extraction.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (out/'counts.json').write_text(json.dumps(counts,indent=2)+'\n',encoding='utf-8')
    return counts


def main():
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('--out',type=Path,default=Path('out'));p.add_argument('--translations',type=Path);p.add_argument('--sheet',type=Path);p.add_argument('--glossary',type=Path);p.add_argument('--include-drafts',action='store_true');args=p.parse_args()
    translations=json.loads(args.translations.read_text(encoding='utf-8')) if args.translations else {}
    existing=None;glossary={}
    if args.sheet:
        with args.sheet.open(encoding='utf-8-sig',newline='') as f:existing=list(csv.DictReader(f))
    if args.glossary:
        with args.glossary.open(encoding='utf-8-sig',newline='') as f:glossary={r['english']:r['hindi'] for r in csv.DictReader(f)}
    counts=write_outputs(extract(args.root),args.out,translations,args.include_drafts,glossary,existing)
    print(json.dumps(counts,indent=2))
if __name__=='__main__':main()
