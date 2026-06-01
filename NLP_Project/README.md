# DeepBrief.AI 🎙️

### Smart Meeting Insights Generator

> Turn a 60-minute meeting recording into a fully structured briefing in under a minute.

DeepBrief.AI is an end-to-end NLP and speech processing pipeline that transcribes meeting audio, extracts key discussion points and decisions, identifies action items with owners and deadlines, and scores the emotional tone of the conversation — all presented through a clean Streamlit dashboard.

---

## Pipeline Overview

```
Audio File
    │
    ▼
[Stage 1] Data Loading & Environment Setup
    │  AMI corpus (HuggingFace) + custom recordings
    ▼
[Stage 2] Speech-to-Text Transcription
    │  Groq API — whisper-large-v3
    ▼
[Stage 3] LLM Summarisation & Action Item Extraction
    │  Claude / GPT-4o — prompt engineering
    ▼
[Stage 4] Sentiment & Tone Analysis
    │  HuggingFace pre-trained classifier (per speaker segment)
    ▼
[Stage 5] Streamlit Dashboard
    │  Single unified interface — upload → run → read
    ▼
[Stage 6] Evaluation
       WER · ROUGE · Manual action item review · Human tone agreement
```

---

## Quickstart

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/deepbrief-ai.git
cd deepbrief-ai
```

### 2. Create a virtual environment

```bash
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Set up environment variables

```bash
cp .env.example .env
# Open .env and fill in your API keys
```

You need:

- **`GROQ_API_KEY`** — from [console.groq.com](https://console.groq.com) (free tier, whisper-turbo-v3)

### 5. Run Stage 1 — load data and validate environment

```bash
python stage1_setup.py
```

This will:

- Check all API keys and packages are configured correctly
- Download 20 representative samples from the AMI corpus
- Save audio files to `data/ami_samples/` and a manifest to `data/samples_manifest.json`

---

## Project Structure

```
deepbrief-ai/
│
├── stage1.py              # Data loading & environment validation
├── stage2.py              # Groq Whisper transcription (coming)
├── stage3_llm.py          # Summarisation & action item extraction (coming)
├── stage4_sentiment.py    # HuggingFace tone analysis (coming)
├── stage5_dashboard.py    # Streamlit app — full pipeline (coming)
├── stage6_evaluation.py   # WER, ROUGE, manual eval (coming)
│
├── data/
│   ├── ami_samples/             # Saved .wav files (gitignored)
│   └── samples_manifest.json    # Sample metadata — tracked
│
├── requirements.txt
├── .env.example
├── .gitignore
└── README.md
```

---

## Dataset

**Primary:** [`edinburghcstr/ami`](https://huggingface.co/datasets/edinburghcstr/ami) — AMI Meeting Corpus  
267,303 rows · ~100 hours · English · Multi-speaker · Timestamped · CC BY 4.0

**Custom:** A recorded group meeting of the project team — used as the live demo input during the oral presentation.

---

## Tech Stack

| Component                    | Technology                           |
| ---------------------------- | ------------------------------------ |
| Speech-to-Text               | Groq API — `whisper-large-v3`        |
| Summarisation & Action Items | Claude (Anthropic) or GPT-4o         |
| Sentiment Analysis           | HuggingFace Transformers             |
| Dashboard                    | Streamlit                            |
| Dataset                      | HuggingFace `datasets`               |
| Evaluation                   | `jiwer` (WER), `rouge-score` (ROUGE) |
| Language                     | Python 3.10+                         |

---

## Evaluation Targets

| Metric                    | Target                                 |
| ------------------------- | -------------------------------------- |
| Word Error Rate (Whisper) | < 25% on AMI test samples              |
| ROUGE-1 (Summarisation)   | > 0.35 vs AMI reference summaries      |
| Action item extraction    | ≥ 70% correct task/owner/deadline      |
| Sentiment agreement       | ≥ 75% human agreement with model label |
| End-to-end speed          | < 60 seconds for a 30-minute recording |

---

## Team

---

## Licence

Dataset: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — AMI Meeting Corpus  
Code: MIT
