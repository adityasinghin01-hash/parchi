
import csv,json,re
from pathlib import Path
import pytest
from hindi_pack import extract,write_outputs,build_catalog,validate_rows
from hindi_pack.extract import PATTERNS,placeholders,glossary_violations
MODULE=Path(__file__).resolve().parents[1]
FIXTURES=Path(__file__).with_name('fixtures')

@pytest.fixture(scope='module')
def result():return extract(FIXTURES)

@pytest.mark.parametrize('name',sorted(PATTERNS))
def test_every_supported_pattern(result,name):
    assert 'Pattern '+name in {e['key'] for e in result['entries']}

@pytest.mark.parametrize('key',['Hello %@, %lld items','%lld medicines','Value %@','Price %@','First line\nSecond line','Raw %lld items','Nested %@ items','Ready %lld%%','Escaped "quote"','Enabled option','Disabled option','Joined ','value','Production retained','Icon label'])
def test_interpolation_multiline_raw_and_expression_keys(result,key):
    assert key in {e['key'] for e in result['entries']}

@pytest.mark.parametrize('key',['Verbatim omitted','identifier-omitted','pills.fill','camera','configuration-omitted','key-omitted','https://example.com','Dolo','650','EEE d MMM','%lld','comment omitted','nested comment omitted','Debug omitted','Nested debug omitted','Theme omitted','Tests omitted'])
def test_skips(result,key):
    assert key not in {e['key'] for e in result['entries']}
    assert key not in '\n'.join(e['expression'] for e in result['not_auto'])

def test_manual_and_not_auto_reporting(result):
    manual={e['key'] for e in result['needs_manual']}
    assert 'Value %@' in manual
    assert 'Hello %@, %lld items' not in manual
    text=' '.join(e['expression'] for e in result['not_auto'])
    assert 'Variable caption' in text and 'Computed caption' in text and 'caption' in text
    assert all(':' in e['where'] and 'String(localized:)' in e['fix'] for e in result['not_auto'])

def row(en='Hello %@ %lld',hi='नमस्ते %@ %lld',status='draft'):
    return {'key':en,'english':en,'hindi':hi,'status':status}

def test_catalog_review_gate():
    assert build_catalog([row()])['strings']=={}
    draft=build_catalog([row()],True)
    assert draft['strings'][row()['key']]['localizations']['hi']['stringUnit']['state']=='needs_review'
    reviewed=build_catalog([row(status='reviewed')])
    assert reviewed['sourceLanguage']=='en' and reviewed['version']=='1.0'
    assert reviewed['strings'][row()['key']]['localizations']['hi']['stringUnit']['state']=='translated'

@pytest.mark.parametrize('r',[row(hi='नमस्ते %@'),row(hi='%lld %@'),row(hi='',status='reviewed'),row(status='unknown')])
def test_validation_blocks_invalid_rows(r):
    assert validate_rows([r])
    with pytest.raises(ValueError):build_catalog([r],True)

def test_placeholder_parity_literal_percent_and_positions():
    assert placeholders('100%% %1$@ %2$lld')==['%1$@','%2$lld']
    assert validate_rows([row('Hello %1$@ %2$lld','नमस्ते %1$@ %2$lld')])==[]
    assert validate_rows([row('Hello %1$@ %2$lld','नमस्ते %2$lld %1$@')])

def test_output_shapes_and_human_review_preserved(result,tmp_path):
    entry=result['entries'][0];translations={e['key']:'ड्राफ्ट '+e['key'] for e in result['entries']}
    counts=write_outputs(result,tmp_path,translations)
    assert counts['found']==len(result['entries'])
    assert counts['catalog_entries']==0
    for name in ['translation-sheet.csv','Localizable.xcstrings','not-auto-localizable.md','report.md','extraction.json','counts.json']:assert (tmp_path/name).exists()
    with (tmp_path/'translation-sheet.csv').open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
    rows[0]['hindi']='समीक्षित '+entry['key'];rows[0]['status']='reviewed'
    write_outputs(result,tmp_path,translations,existing_rows=rows)
    catalog=json.loads((tmp_path/'Localizable.xcstrings').read_text(encoding='utf-8'))
    assert len(catalog['strings'])==1
    assert catalog['strings'][entry['key']]['localizations']['hi']['stringUnit']['value']==rows[0]['hindi']

def test_glossary_longest_phrase_and_violation():
    assert not glossary_violations([row('Plan B','Plan B')],{'plan':'प्लान','Plan B':'Plan B'})
    assert glossary_violations([row('medicine','टेस्ट')],{'medicine':'दवा'})

def test_real_app_extraction_and_all_drafts_complete():
    root=MODULE.parents[2]/'app/Parchi'
    result=extract(root)
    assert result['files']>0 and result['entries']
    translations=json.loads((MODULE/'draft-translations.json').read_text(encoding='utf-8'))
    rows=[row(e['key'],translations.get(e['key'],'')) for e in result['entries']]
    assert all(r['hindi'].strip() for r in rows)
    assert not validate_rows(rows)
    with (MODULE/'glossary.csv').open(encoding='utf-8',newline='') as f:glossary={r['english']:r['hindi'] for r in csv.DictReader(f)}
    assert not glossary_violations(rows,glossary)

def test_no_network(monkeypatch):
    import socket
    monkeypatch.setattr(socket,'socket',lambda *a,**k:pytest.fail('network attempted'))
    extract(FIXTURES)


def test_missing_source_is_an_error(tmp_path):
    with pytest.raises(ValueError):extract(tmp_path/'does-not-exist')

def test_duplicates_merge_and_debug_else_is_retained(tmp_path):
    (tmp_path/'One.swift').write_text('Text("Repeated")\n#if DEBUG\nText("Hidden")\n#else\nText("Visible")\n#endif\nText("Repeated")',encoding='utf-8')
    result=extract(tmp_path)
    repeated=next(e for e in result['entries'] if e['key']=='Repeated')
    assert len(repeated['locations'])==2
    assert {e['key'] for e in result['entries']}=={'Repeated','Visible'}
