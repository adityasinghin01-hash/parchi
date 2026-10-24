import argparse,json,sys
from .core import generate

def main():
    if hasattr(sys.stdout, "reconfigure"): sys.stdout.reconfigure(encoding="utf-8")
    parser=argparse.ArgumentParser(description="Offline complaint draft: JSON file or stdin")
    parser.add_argument("input",nargs="?")
    args=parser.parse_args()
    try:
        if args.input:
            with open(args.input,encoding="utf-8") as f: payload=json.load(f)
        else: payload=json.load(sys.stdin)
        print(json.dumps(generate(payload),ensure_ascii=False,indent=2))
    except (ValueError,TypeError,KeyError) as exc:
        parser.exit(2,str(exc)+"\n")
if __name__=="__main__": main()
