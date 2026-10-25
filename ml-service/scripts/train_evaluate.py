"""Reproducible held-out evaluation for the HRMS DWDM demo dataset.
Run from ml-service/: python scripts/train_evaluate.py
Metrics demonstrate the pipeline, not expected performance on real hostel records.
"""
import csv
import json
from pathlib import Path
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "maintenance_tickets.csv"
REPORT_DIR = ROOT / "reports"
RANDOM_STATE = 42
TEST_SIZE = 0.2

def read_dataset():
    with DATA_PATH.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    required = {"text", "category", "priority"}
    if not rows or not required.issubset(rows[0]):
        raise ValueError("Dataset must have text, category, and priority columns.")
    if any(not row["text"].strip() or not row["category"].strip() or not row["priority"].strip() for row in rows):
        raise ValueError("Dataset contains an empty text or label.")
    return rows

def make_pipeline():
    return Pipeline([
        ("tfidf", TfidfVectorizer(lowercase=True, ngram_range=(1, 2), strip_accents="unicode")),
        ("classifier", MultinomialNB(alpha=0.25)),
    ])

def evaluate_target(rows, target):
    x = [row["text"] for row in rows]
    y = [row[target] for row in rows]
    counts = {label: y.count(label) for label in sorted(set(y))}
    if min(counts.values()) < 2:
        raise ValueError(f"Each {target} class needs at least two rows for stratified evaluation.")
    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y
    )
    model = make_pipeline()
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)
    labels = sorted(set(y))
    report = classification_report(y_test, predictions, labels=labels, output_dict=True, zero_division=0)
    matrix = confusion_matrix(y_test, predictions, labels=labels).tolist()
    majority_label = sorted(set(y_train), key=lambda label: (-y_train.count(label), label))[0]
    baseline_predictions = [majority_label] * len(y_test)
    return {
        "target": target, "rows_total": len(rows), "train_rows": len(x_train), "test_rows": len(x_test),
        "random_state": RANDOM_STATE, "test_size": TEST_SIZE, "classes": labels,
        "class_distribution": counts,
        "accuracy": round(float(accuracy_score(y_test, predictions)), 4),
        "majority_baseline_accuracy": round(float(accuracy_score(y_test, baseline_predictions)), 4),
        "classification_report": report, "confusion_matrix": matrix,
        "confusion_matrix_label_order": labels,
    }

def main():
    rows = read_dataset()
    result = {
        "project": "Hostel Room Management System - DWDM",
        "dataset": "synthetic academic demonstration dataset",
        "dataset_path": "data/maintenance_tickets.csv",
        "warning": "Do not present these synthetic-data metrics as real-world accuracy.",
        "models": {"category": evaluate_target(rows, "category"), "priority": evaluate_target(rows, "priority")},
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    output = REPORT_DIR / "evaluation_results.json"
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"
Saved report to: {output}")

if __name__ == "__main__":
    main()
