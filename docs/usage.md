# Usage

## Public API

DOMINO exposes two user-facing functions:

- `detect(G, A, ...) -> dict`, recommended wrapper that may also trigger optional
  reporting and visualisation.
- `detect_communities(G, A, ...) -> (Partition, bic)`, core solver that returns
  the final partition and BIC without side effects.

Most users should call `detect`.

## Inputs

### Graph `G`
`G` is a `networkx.Graph` used by the Leiden engine. For best results, the edge
support of `G` should match the nonzero pattern of the matrix input.

### Matrix `A`
`A` must be a square matrix of shape `(N, N)`.

- `mode="binary"`: `A` is interpreted as an adjacency-like matrix. Nonzero
  entries define the binary support.
- `mode="signed"`: either provide a single signed matrix `A` with positive and
  negative entries, or provide positive and negative layers explicitly via
  `A` and `Aneg`.
- `mode="weighted"`: `A` is a nonnegative weight matrix.

DOMINO enforces symmetry by averaging, and sets the diagonal to zero.

## Typical call

```python
from domino import detect

res = detect(
    G,
    A,
    mode="binary",
    degree_corrected=False,
    max_outer=3,
    theta=0.0,
    gamma=0.0,
)
part = res["partition"]
bic = res["bic"]
```

## Key parameters

- `mode`: `"binary"`, `"signed"`, `"weighted"`.
- `degree_corrected`: toggles dc variants of the models.
- `max_outer`: maximum number of outer iterations of the alternating scheme.
- `theta`, `gamma`: Leiden resolution parameters, set to `0.0` in most BIC runs.
- `target_K`: if provided, attempts to select a partition with exactly `K`
  communities.
- `viz`, `report`: booleans or dictionaries enabling optional post-processing.

## Output

`detect` returns a dictionary containing at least:
- `partition`: `domino.leiden.partitions_functions.Partition`
- `bic`: `float`

Depending on flags, it may include additional fields produced by the optional
post-processing routine.

## Signed input patterns

Signed from a single signed matrix:
```python
res = detect(G, A_signed, mode="signed")
```

Signed from explicit layers:
```python
res = detect(G, Apos, Aneg=Aneg, mode="signed")
```

In both cases, `G` should represent the union support, i.e. edges where
$|A_{ij}| > 0$.
