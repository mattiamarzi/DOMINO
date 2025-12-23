# Contributing to DOMINO

## Development setup

Create a virtual environment and install the package in editable mode:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
python -m pip install -e ".[viz,dev]"
```

## Running tests

```bash
pytest -q
```

## Linting and formatting

DOMINO uses `ruff` for linting and formatting.

```bash
ruff check .
ruff format .
```

## Pre-commit

Install hooks once:

```bash
pre-commit install
```

Run on all files:

```bash
pre-commit run --all-files
```

## Guidelines for new code

- Prefer deterministic tests with fixed random seeds.
- Keep synthetic test graphs small and fast (e.g., $N=100$).
- Ensure public API changes are reflected in `README.md` and in `docs/`.
