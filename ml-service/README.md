# HRMS ML Service

This folder contains the Python service used by the DWDM component.

## Folder structure

```text
ml-service/
├── data/
│   └── maintenance_tickets.csv    # 60 synthetic labelled examples
├── reports/
│   ├── README.md                  # How to interpret generated metrics
│   └── evaluation_results.json    # Generated locally; not committed by default
├── scripts/
│   └── train_evaluate.py          # Reproducible held-out evaluation
├── app.py                         # FastAPI endpoints and classifiers
├── requirements.txt               # Python dependencies
└── test_app.py                    # Automated tests
```

## Setup (Windows PowerShell)

From repository root:

```powershell
cd ml-service
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

Health check: `http://localhost:8000/health`  
Interactive docs: `http://localhost:8000/docs`

## Endpoints

- `GET /health` — service health.
- `POST /predict-maintenance` — JSON input: `{"title":"Leaking tap","description":"Water is dripping under the sink"}`.
- `POST /analytics` — selected maintenance records in; category, priority, status, monthly volume and resolution-time summaries out.

The Flutter application should call these through the authenticated Node API. Do not use the Python service as an authorization substitute.

## Algorithms

1. TF-IDF transforms issue text into weighted token/ngram features.
2. Separate Multinomial Naive Bayes classifiers predict category and priority.
3. Data mining counts ticket labels and calculates monthly counts and average resolution duration.

## Run tests and evaluate

```powershell
python -m unittest discover -s . -p test_app.py
python scripts/train_evaluate.py
```

The report is written to `reports/evaluation_results.json` and includes a deterministic stratified 80/20 split, per-class precision/recall/F1, confusion matrices, and a majority-class baseline.

## Dataset warning

The CSV is a small synthetic academic dataset. It demonstrates a pipeline but is not evidence of real-world accuracy. Use reviewed, de-identified data and an independent test set before making reliability claims.
