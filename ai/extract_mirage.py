import sys, os, io, json, pyarrow.parquet as pq
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
t = pq.read_table(src).to_pylist()
labels = {}
for i, r in enumerate(t):
    img = r['image']; b = img['bytes'] if isinstance(img, dict) else img
    ext = '.png' if b[:4] == b'\x89PNG' else '.jpg'
    fn = f'rx{i:03d}{ext}'
    open(os.path.join(out, fn), 'wb').write(b)
    labels[fn] = r['medicines']
json.dump(labels, open(os.path.join(out, 'labels.json'), 'w'), indent=1, ensure_ascii=False)
print(len(t)); [print(k, '->', v) for k, v in list(labels.items())[:6]]
