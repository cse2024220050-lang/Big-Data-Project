# UrbanCart Big Data Term Project

This repository contains a complete, reproducible analytics pipeline for UrbanCart using SQLite, pandas, NumPy, and matplotlib.

## Run

```bash
python -m venv .venv
# Windows Git Bash
source .venv/Scripts/activate
pip install -r requirements.txt
jupyter notebook notebooks/analysis.ipynb
```

The completed outputs are already stored in `data/processed/`, `figures/`, and `report/`. All ten SQL queries are in `sql/queries.sql`.

## Main findings

- Top RFM revenue segment: **Loyal** ($2,334,550.52).
- Highest cleaned effective margin: **Electronics** (52.40%).
- Price cleaning changed the leading revenue category from **Books & Media** to **Apparel**.
- Rating/repeat correlation: **0.076**.
- Highest simulated 30-day stockout risk: **Those Non-Fiction** (69.26%).

## Contribution statement (edit names before submission)

The team jointly reviewed the business requirements and final conclusions. Team Member 1 inspected the SQLite schema, wrote and validated the ten SQL queries, and connected query results to pandas. Team Member 2 cleaned the customer and review data, standardized four legacy date formats, resolved duplicate and near-duplicate customer records, and documented missing-value policies. Team Member 3 reconciled the product catalog, investigated price outliers, removed duplicate order-item business rows, and implemented the revenue, cost, margin, and return rules. Team Member 4 implemented the NumPy RFM scoring, cosine-similarity recommendations, normal-equation regression, Monte Carlo stockout simulation, and chart generation. All members reviewed the report, checked the processed files, and confirmed that the GitHub repository runs from the documented folder structure. Replace these role labels with the actual names and adjust the description so it accurately represents the final contribution of each person.
