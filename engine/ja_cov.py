import csv,json,re,sys,collections,random
S=sys.argv[1]; OUT="/Users/aditya/dev/parchi-research/phase3-mapping"
rows=[r for r in csv.DictReader(open(f"{S}/data/medlex/indian_medicine_data.csv",encoding="utf8")) if r["Is_discontinued"].strip().upper()=="FALSE"]
ja=[x for x in json.load(open("/Users/aditya/dev/parchi-research/phase5-prices/janaushadhi_products_2026-10-23.json"))["responseBody"]["newProductResponsesList"] if x.get("mrp")]
FORMS={"tablet":["TAB","TABLET","TABS"],"capsule":["CAP","CAPSULE","CAPS"],"liquid":["SYP","SYR","SYRUP","SUSP","SUSPENSION","LIQUID","SOLUTION","DROPS","DROP"],
       "injection":["INJ","INJECTION"],"inhaler":["MDI","INHALER","ROTACAP","ROTACAPS","RESPULES","NEB"],"topical":["OINT","OINTMENT","CREAM","GEL","LOTION"],"gargle":["GARGLE","MOUTHWASH"],"powder":["PWD","POWDER","SACHET","GRANULES"]}
ALLFORM=set(sum(FORMS.values(),[]))
def form_of(text):
    t=set(re.findall(r"[A-Z]+",text.upper()))
    for f,keys in FORMS.items():
        if t & set(keys): return f
    return None
JAFORM={"tablet":r"tablet","capsule":r"capsule","liquid":r"syrup|suspension|solution|drops|liquid","injection":r"injection","inhaler":r"inhal|respules|rotacap|nebul","topical":r"ointment|cream|gel|lotion","gargle":r"gargle|mouthwash|solution","powder":r"powder|sachet|granules"}
def salts(comp):
    out=[]
    for part in (comp or "").split("+"):
        m=re.match(r"\s*([A-Za-z][A-Za-z \-]+?)\s*\(([\d.]+)\s*(mg|mcg|gm|g|iu|%|ml)",part.strip(),re.I)
        if m: out.append((m.group(1).strip().lower(),m.group(2)))
    return out
by_stem=collections.defaultdict(list)
for r in rows:
    p=r["name"].split()
    m=re.match(r"[A-Za-z]+",p[0]) if p else None
    if m: by_stem[m.group(0).upper()].append(r)
def pick_product(stem,item):
    words=item.upper().replace("-"," ").split()
    variant=[w for w in words[1:] if w.isalpha() and len(w)<=3 and w not in ALLFORM and w not in ("MG","ML","IP")]
    nums=re.findall(r"\d+(?:\.\d+)?",item)
    f=form_of(item); best=None; bs=-99
    for r in by_stem.get(stem,[]):
        n=r["name"].upper().replace("-"," "); fn=form_of(n); s=0
        if f and fn==f: s+=4
        elif f and fn and fn!=f: s-=4
        s+=sum(3 for v in variant if re.search(r"\b"+v+r"\b",n))
        rest=n.split(" ",1)[1] if " " in n else ""
        s-=sum(2 for v in re.findall(r"\b[A-Z]{2,3}\b",rest) if v not in variant and v not in ALLFORM and v not in ("MG","ML","IP","DUO","SR","XR","CR","ER","OF","IN"))
        s+=sum(2 for x in nums if re.search(r"\b"+re.escape(x)+r"\b",n))
        if s>bs: bs=s; best=r
    return best,f
def ja_match(sl,f):
    for x in ja:
        n=x["genericName"].lower()
        if not all(s.split()[0] in n for s,_ in sl): continue
        if not all(re.search(r"(?<![\d.])"+re.escape(st)+r"\s*(mg|mcg|g|iu|%)",n) for _,st in sl): continue
        if len(re.findall(r"\band\b|,",n))+1!=len(sl): continue
        if f and not re.search(JAFORM[f],n): continue
        return x
    return None
lab=json.load(open(f"{S}/data/mirage100/img/labels.json"))
stats=collections.Counter(); ex=[]
for l in lab.values():
    if not l or l=="None": continue
    for item in l.split(","):
        item=item.strip(); w=item.split()
        m=re.match(r"[A-Za-z]+",w[0]) if w else None
        if not m or len(m.group(0))<3: continue
        stem=m.group(0).upper(); stats["mentions"]+=1
        if stem not in by_stem: stats["not_in_catalogue"]+=1; continue
        prod,f=pick_product(stem,item)
        if prod is None: stats["not_in_catalogue"]+=1; continue
        sl=salts(prod["short_composition1"])+salts(prod["short_composition2"])
        if not sl: stats["no_composition"]+=1; continue
        mt=ja_match(sl,f or form_of(prod["name"]))
        if mt: stats["ja_equivalent"]+=1; ex.append((item,prod["name"],mt["genericName"],mt["unitSize"],mt["mrp"]))
        else: stats["no_ja_equivalent"]+=1
t=stats["mentions"]; known=stats["ja_equivalent"]+stats["no_ja_equivalent"]
print(dict(stats))
print(f"JA equivalent (same salts+strength+form): {stats['ja_equivalent']}/{t} = {stats['ja_equivalent']/t:.1%} of all mentions; {stats['ja_equivalent']}/{known} = {stats['ja_equivalent']/known:.1%} of mentions with known composition")
random.seed(1)
for e in random.sample(ex,min(15,len(ex))): print(" ",e)
json.dump({"stats":stats,"examples":ex},open(f"{OUT}/mirage_janaushadhi_coverage_formaware.json","w"),indent=1,default=str)
