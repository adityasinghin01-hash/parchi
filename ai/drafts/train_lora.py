"""LoRA fine-tune of Qwen2.5-VL on Parchi data (DGX A100 40 GB or Jarvis A100 80 GB).

Usage:
  python train_lora.py --base Qwen/Qwen2.5-VL-7B-Instruct --manifest data/train.jsonl --out runs/7b_lora \
      [--max-samples 40000] [--rank 64] [--lr 1e-4] [--batch 2] [--accum 8] [--max-side 1024]

Each manifest line: {"image": "<path>", "target": "<JSON string the model must output>", "prompt": optional}
Resumes automatically from the last checkpoint in --out. Prints seconds/step and ETA every 10 steps.
"""
import argparse, glob, json, os, random, time

import torch
from PIL import Image
from peft import LoraConfig, get_peft_model
from transformers import (AutoProcessor, Qwen2_5_VLForConditionalGeneration, Trainer, TrainerCallback,
                          TrainingArguments)

from parchi_prompt import PROMPT

ap = argparse.ArgumentParser()
ap.add_argument("--base", default="Qwen/Qwen2.5-VL-7B-Instruct")
ap.add_argument("--manifest", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--max-samples", type=int, default=0)
ap.add_argument("--rank", type=int, default=64)
ap.add_argument("--lr", type=float, default=1e-4)
ap.add_argument("--batch", type=int, default=2)
ap.add_argument("--accum", type=int, default=8)
ap.add_argument("--epochs", type=float, default=1.0)
ap.add_argument("--max-side", type=int, default=1024)
ap.add_argument("--workers", type=int, default=16)
ap.add_argument("--save-steps", type=int, default=200)
a = ap.parse_args()

rows = [json.loads(l) for l in open(a.manifest, encoding="utf8")]
random.Random(0).shuffle(rows)
if a.max_samples:
    rows = rows[: a.max_samples]
print(f"training rows: {len(rows)}", flush=True)

processor = AutoProcessor.from_pretrained(a.base, min_pixels=128 * 28 * 28, max_pixels=1280 * 28 * 28)
tok = processor.tokenizer
tok.padding_side = "right"
model = Qwen2_5_VLForConditionalGeneration.from_pretrained(a.base, torch_dtype=torch.bfloat16, attn_implementation="sdpa")
model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={"use_reentrant": False})
model.enable_input_require_grads()
model = get_peft_model(model, LoraConfig(
    r=a.rank, lora_alpha=2 * a.rank, lora_dropout=0.05, bias="none", task_type="CAUSAL_LM",
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]))
model.print_trainable_parameters()

ASSIST = tok.encode("<|im_start|>assistant\n", add_special_tokens=False)


def load(path):
    im = Image.open(path).convert("RGB")
    im.thumbnail((a.max_side, a.max_side))
    return im


class RxSet(torch.utils.data.Dataset):
    def __len__(self):
        return len(rows)

    def __getitem__(self, i):
        r = rows[i]
        try:
            img = load(r["image"])
        except Exception:  # a broken file must not kill a night-long run
            return self[(i + 1) % len(rows)]
        msgs = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": r.get("prompt") or PROMPT}]},
                {"role": "assistant", "content": [{"type": "text", "text": r["target"]}]}]
        return {"text": processor.apply_chat_template(msgs, tokenize=False, add_generation_prompt=False), "image": img}


def collate(batch):
    enc = processor(text=[b["text"] for b in batch], images=[b["image"] for b in batch], return_tensors="pt", padding=True)
    labels = enc["input_ids"].clone()
    for j, ids in enumerate(enc["input_ids"].tolist()):
        start = 0
        for k in range(len(ids) - len(ASSIST), -1, -1):  # last "<|im_start|>assistant\n": train only on the answer
            if ids[k:k + len(ASSIST)] == ASSIST:
                start = k + len(ASSIST)
                break
        labels[j, :start] = -100
    labels[enc["attention_mask"] == 0] = -100
    enc["labels"] = labels
    return enc


class Clock(TrainerCallback):
    def on_train_begin(self, args, state, control, **kw):
        self.t0, self.s0 = time.time(), state.global_step

    def on_log(self, args, state, control, logs=None, **kw):
        done = state.global_step - self.s0
        if done > 0:
            sps = (time.time() - self.t0) / done
            left = (state.max_steps - state.global_step) * sps
            print(f"step {state.global_step}/{state.max_steps}  {sps:.1f} s/step  ETA {left / 3600:.1f} h  {logs}", flush=True)


args = TrainingArguments(
    output_dir=a.out, per_device_train_batch_size=a.batch, gradient_accumulation_steps=a.accum,
    num_train_epochs=a.epochs, learning_rate=a.lr, lr_scheduler_type="cosine", warmup_ratio=0.03,
    bf16=True, logging_steps=10, save_steps=a.save_steps, save_total_limit=3, report_to="none",
    dataloader_num_workers=a.workers, remove_unused_columns=False, gradient_checkpointing=False,  # enabled above
    optim="adamw_torch", weight_decay=0.0, max_grad_norm=1.0, seed=3407)
trainer = Trainer(model=model, args=args, train_dataset=RxSet(), data_collator=collate, callbacks=[Clock()])
resume = bool(glob.glob(os.path.join(a.out, "checkpoint-*")))
trainer.train(resume_from_checkpoint=resume or None)
model.save_pretrained(os.path.join(a.out, "final_lora"))
processor.save_pretrained(os.path.join(a.out, "final_lora"))
print("saved", os.path.join(a.out, "final_lora"))
