# DWDM Implementation Guide — HRMS Maintenance Intelligence

## 1. Problem statement

Hostel maintenance reports are short text descriptions. Staff need to group them into categories, assign an initial priority, and understand common request patterns.

## 2. Objectives

- Classify reports into Plumbing, Electrical, Cleanliness, Furniture, or Other.
- Suggest priority: low, normal, high, or urgent.
- Summarise category, priority, and status.
- Analyse monthly request volume and average resolution time.
- Evaluate the model with held-out data and a baseline.

## 3. Dataset

File: `ml-service/data/maintenance_tickets.csv`

| Column | Meaning |
|---|---|
| `text` | Maintenance issue description |
| `category` | Category target label |
| `priority` | Priority target label |

The current dataset contains 60 synthetic examples, balanced across five categories and four priorities. It is educational demo data, not real hostel data. Clearly state this in the report.

## 4. ML pipeline

1. Load and validate the CSV.
2. Combine title and description for live predictions.
3. Apply TF-IDF with unigrams and bigrams.
4. Train separate Multinomial Naive Bayes classifiers for category and priority.
5. Return predicted labels and maximum class probabilities.
6. Require staff review before action.

A maximum class probability is not a calibrated guarantee of correctness.

## 5. Data-mining pipeline

The authenticated Node API reads up to 1,000 recent maintenance records from MongoDB and sends selected fields to Python. Python calculates frequency by category, priority and status, monthly request counts, and average resolution time for valid resolved records.

## 6. Run the implementation

Follow the root README to start the Node API, Python service, and Flutter app. Sign in as staff and open **ML Insights**.

## 7. Tests and evaluation

From `ml-service/`:

```powershell
python -m unittest discover -s . -p test_app.py
python scripts/train_evaluate.py
```

The script uses a deterministic stratified 80/20 split. It reports accuracy, majority-class baseline accuracy, per-class precision/recall/F1, and confusion matrices for category and priority.

## 8. Report checklist

1. Abstract and problem statement.
2. Objectives and scope.
3. Dataset schema, source, class counts and labelling rules.
4. Preprocessing and TF-IDF explanation.
5. Multinomial Naive Bayes explanation.
6. Train/test split and random seed.
7. Results and confusion matrices.
8. Data-mining summaries and ML Insights screenshots.
9. Limitations, ethical handling and future improvements.
10. Conclusion and references.

## 9. Limitations and future work

- Small synthetic data does not represent real hostel language.
- Labels may be ambiguous.
- Urgent-case recall needs special attention.
- The model needs larger reviewed, de-identified data and independent validation.
- Staff must make the final decision, especially for urgent safety issues.

Never claim production accuracy based only on synthetic-data results.
