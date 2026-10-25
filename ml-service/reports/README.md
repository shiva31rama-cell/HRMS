# Evaluation reports

Run from `ml-service/`:

```powershell
python scripts/train_evaluate.py
```

This generates `evaluation_results.json` in this folder.

## Included metrics
- Dataset type and file path
- Train/test sizes and deterministic random seed
- Class distributions
- Held-out accuracy and majority-class baseline accuracy
- Per-class precision, recall, F1-score and support
- Confusion matrices and their label order

## Interpretation
The bundled CSV contains synthetic, hand-labelled educational examples. Results demonstrate reproducible evaluation only and must not be presented as expected performance on real hostel tickets.
