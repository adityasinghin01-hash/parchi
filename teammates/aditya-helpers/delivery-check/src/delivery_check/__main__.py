import argparse,json,sys
from .core import compare

def main():
    if hasattr(sys.stdout,'reconfigure'):sys.stdout.reconfigure(encoding='utf-8')
    p=argparse.ArgumentParser();p.add_argument('input');p.add_argument('--catalogue');args=p.parse_args()
    try:
        with open(args.input,encoding='utf-8') as f:payload=json.load(f)
        print(json.dumps(compare(payload,args.catalogue),ensure_ascii=False,indent=2))
    except (ValueError,KeyError,TypeError) as exc:p.exit(2,str(exc)+'\n')
if __name__=='__main__':main()
