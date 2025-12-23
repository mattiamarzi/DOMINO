# Leiden + BIC — API Quick Reference (Copy‑Paste Friendly)

> This page documents exactly the functions you’ll call most often, all parameters you might tweak,
> and our recommended defaults. It also clarifies the automatic guards/coercions performed by the
> unified entry point.

---

## Index

- [`detect(...)`](#detect) — recommended entry point (optional plotting and/or reporting)
- [`detect_communities(...)`](#detect_communities) — core solver (no plotting, no printing)
- [`process_graph(...)`](#process_graph) — plotting/report helper (advanced users)
- [Parameter cheat sheet](#parameter-cheat-sheet) — quick meanings + recommended defaults
- [Usage patterns](#usage-patterns) — copy-paste code snippets for common cases
- [Notes on performance and reproducibility](#notes-on-performance-and-reproducibility)

---

## `detect(...)`

`detect` is the recommended entry point. It runs community detection and can optionally produce
plots and/or a textual report.

### Signature

```python
detect(
    G,
    A,
    *,
    mode="binary",
    Aneg=None,
    degree_corrected=False,
    initial_partition=None,
    theta=0.0,
    gamma=0.0,
    max_outer=5,
    do_macro_merge=False,
    target_K=None,
    fix_x=None,
    viz=False,        # bool OR dict of kwargs forwarded to process_graph
    report=False,     # bool OR dict of kwargs forwarded to process_graph
) -> dict

### Returns

A dictionary with at least:

- **`"partition"`** — a flattened `Partition` (iterable of `set[int]`).
- **`"bic"`** — the best (lowest) BIC value attained.

### What this function does

- Calls `detect_communities(...)` internally to obtain `(partition, bic)`.
- If `viz=True` and/or `report=True`, calls `process_graph(...)`.

---

## `detect_communities(...)`

### Signature

```python
detect_communities(
    G,                              # networkx.Graph (weighted or unweighted)
    A,                              # numpy.ndarray (adjacency / signed / weighted)
    *,                              # (keyword-only below)
    mode="binary",                  # "binary" | "signed" | "weighted"
    Aneg=None,                      # ONLY for mode="signed": optional negative layer
    degree_corrected=False,         # False → SBM/sSBM/wSBM; True → dcSBM/sdcSBM/wdcSBM
    initial_partition=None,         # None | "modularity" | "pos_modularity"(signed) | partition-like
    theta=0.0,                      # Advanced (rarely needed)
    gamma=0.0,                      # Advanced (rarely needed)
    max_outer=5,                   # Max Leiden ↔ parameter re-fit cycles
    do_macro_merge=False,           # Optional BIC-based macro merges after each pass
    target_K=None,                  # Enforce exactly K communities (BIC-aware greedy merges)
    fix_x=None                      # dc* only; default True (freeze x after first solve)
) -> (Partition, float)
```

### Returns

- **`Partition`** — a flattened partition (iterable of `set[int]`, each set = community of node ids).  
- **`float`** — the best (lowest) **BIC** value attained.

### What this function does

- **Matrix hygiene** (always):
  - Ensures symmetry: if not, warns and uses `0.5 * (M + M.T)`.
  - Sets diagonal to zero.
- **Guards & coercions by `mode`:**
  - `mode="binary"`
    - If negatives exist → **warn** and **union‑binarize**: `Abin = 1{A != 0}` (suggest using `mode="signed"`).
    - If weights exist → **warn** and **binarize**: `Abin = 1{A > 0}` (suggest `mode="weighted"`).
  - `mode="signed"`
    - If a single signed matrix `A` is provided → **sign‑binarize** into `Apos = 1{A>0}`, `Aneg = 1{A<0}`.
    - If no negatives are found → **error** (use `"binary"` or provide a proper negative layer).
  - `mode="weighted"`
    - If negatives exist → **warn** and take `abs(A)` (signed‑weighted not implemented here).
    - If fractional positive weights exist → **warn** (the geometric ME model acts as a **quasi‑likelihood**).
- **Model & Optimization**:
  - Runs Leiden while **maximizing −BIC** for your chosen model family:
    - `"binary"` → SBM or **dcSBM** if `degree_corrected=True`.
    - `"signed"` → signed SBM or **signed dcSBM**.
    - `"weighted"` → geometric wSBM or **weighted dcSBM**.
  - For degree‑corrected variants (dc*), we alternate *Leiden pass → parameter update* for up to `max_outer` rounds.
  - If `fix_x=True` (default in dc*), node factors \(x_i\) are solved **once** (UBCM/SCM/WCM) then **frozen**; only block affinities \(\chi_{rs}\) are refreshed. This is faster and typically stable.

### Parameters (full list)

| Name | Type | Default | Applies to | Meaning / Behavior | Recommendation |
|---|---|---:|---|---|---|
| `mode` | `str` | `"binary"` | all | Model family: `"binary"`, `"signed"`, `"weighted"` | Match your data; use `"signed"` only if you truly have negative edges |
| `Aneg` | `np.ndarray or None` | `None` | signed | Optional **negative** layer if you pass `A` as positive layer | Usually pass a single signed matrix and let it split layers |
| `degree_corrected` | `bool` | `False` | all | Turn on node factors \(x_i\) and block affinities \(\chi_{rs}\) | Use `True` if degree/strength heterogeneity is strong |
| `initial_partition` | `None` / `str` / partition‑like | `None` | all | Warm start: `"modularity"` in all modes; `"pos_modularity"` for signed; or pass a partition | `None` is fine; try `"modularity"` on large/noisy graphs |
| `max_outer` | `int` | `5` | dc* esp. | Max *Leiden ↔ parameter* outer iterations | 5–10 is typical; 3 often enough |
| `do_macro_merge` | `bool` | `False` | all | After each pass, greedily merge blocks when BIC improves | Leave `False`; enable when you want extra coarsening |
| `target_K` | `int or None` | `None` | all | Enforce **exactly K** communities via BIC‑aware merges | Use when you need a fixed K (model‑aware) |
| `fix_x` | `bool or None` | `True` (dc*) | dc* only | Freeze \(x_i\) after the first solve (UBCM/SCM/WCM) | **True** is robust & fast; set `False` to fully re‑fit every outer loop |

### Advanced (rarely needed)

| Name | Type | Default | Meaning |
|---|---|---:|---|
| `theta` | `float` | `0.0` | Leiden refinement temperature for stochastic tie-breaking. Keep 0.0 unless you know you need it. |
| `gamma` | `float` | `0.0` | Leiden boundary/cut filter. Keep 0.0 unless you know you need it. |

---

## `process_graph(...)`

> Helper to **visualize** the detected partition and optionally print summary stats.  
> We document the public surface; exact implementation details may vary per release.

Most users should prefer `detect(..., viz=True, report=True)` instead of calling `process_graph(...)` directly.

### Signature

```python
process_graph(
    G,                              # networkx.Graph (same node ids used in detection)
    detected_labels,                # 1D array-like of community labels per node (or Partition)
    *,                              # (keyword-only below)
    layout_type="custom",           # "custom" | "kshell" | "kamada" | None
    pos=None,                       # dict(node -> (x,y)) if layout_type="custom"
    print_info=True                 # True → print partition stats/summary
) -> dict or None                   # returns the 'pos' dict if a layout is produced
```

### Behavior

- **Inputs**
  - `detected_labels` can be:
    - a flat `Partition` (iterable of sets of node ids), or
    - a 1D array‑like of integer labels aligned with `G`’s node order.
- **Layouts**
  - `layout_type="custom"`: you provide `pos` (`dict[node] -> (x, y)`). Use this when you already computed coordinates.
  - `layout_type="kshell"`: position nodes by **k‑shell** structure and group communities visually.
  - `layout_type="kamada"`: compute a **Kamada‑Kawai** layout (spring embedding); communities are plotted distinctly.
  - `layout_type=None`: no geometric layout; plots nodes grouped by community (blocks placed together).
- **Output**
  - When a layout is computed or supplied, returns the `pos` dictionary for reuse/export; otherwise returns `None`.
- **Printing**
  - If `print_info=True`, prints high‑level summary (e.g., #communities, size distribution, BIC if available).

### Recommended use

- Start with `layout_type="kamada"` for quick, legible pictures.  
- Use `layout_type="kshell"` when degree structure is key to interpretation.  
- Use `layout_type="custom"` to keep your own embedding (e.g., from node2vec/UMAP).

---

## Parameter Cheat Sheet

- **Model family**
  - `"binary"`: unweighted, unsigned graphs (we will binarize if weights exist).  
  - `"signed"`: graphs with positive and negative edges (we **sign‑binarize** a signed matrix).  
  - `"weighted"`: nonnegative weights; if negatives show up, we use `abs()` with a warning.
- **Degree correction (`degree_corrected=True`)**
  - Adds node factors \(x_i\) and block affinities \(\chi_{rs}\).  
  - Defaults to **freezing** \(x_i\) after an initial UBCM/SCM/WCM solve (`fix_x=True`), then iteratively updating only \(\chi_{rs}\) between Leiden passes.
- **Leiden knobs (advanced)**
  - `theta` and `gamma` default to `0.0`. Keep them at `0.0` unless you know you need them.
- **Outer iterations**
  - `max_outer` bounds the number of *Leiden pass ↔ parameter updates* cycles. 5–10 is a sensible band.
- **Target K**
  - `target_K` greedily merges communities (using the model’s BIC) until **exactly K** remain—useful when you need a fixed granularity.

---

## Usage Patterns

### Recommended: run detection with optional plots/report

```python
from domino import detect
import networkx as nx, numpy as np

A = (np.random.rand(200, 200) < 0.05).astype(float)
np.fill_diagonal(A, 0)
A = np.maximum(A, A.T)  # symmetrize
G = nx.from_numpy_array(A)

res = detect(G, A, mode="binary", degree_corrected=True, viz=True, report=True)
part = res["partition"]
bic = res["bic"]
print(f"#communities: {len(part)}, BIC: {bic:.2f}")
```

### Binary graph (SBM) — vanilla

```python
from domino.detect import detect_communities
import networkx as nx, numpy as np

A = (np.random.rand(200, 200) < 0.05).astype(float)
np.fill_diagonal(A, 0)
A = np.maximum(A, A.T)  # symmetrize
G = nx.from_numpy_array(A)

part, bic = detect_communities(G, A, mode="binary", degree_corrected=False)
print(f"#communities: {len(part)}, BIC: {bic:.2f}")
```

### Binary graph (dcSBM) — degree corrected (freeze \(x\))

```python
part_dc, bic_dc = detect_communities(
    G, A,
    mode="binary",
    degree_corrected=True,
    fix_x=True,           # recommended default
    max_outer=5
)
```

### Signed graph (sSBM) — pass one signed matrix

```python
S = np.random.choice([-1, 0, +1], size=(150, 150), p=[0.02, 0.94, 0.04]).astype(float)
np.fill_diagonal(S, 0)
S = 0.5 * (S + S.T)

part_s, bic_s = detect_communities(
    nx.from_numpy_array((S != 0).astype(float)),
    S,
    mode="signed",
    degree_corrected=False
)
```

### Signed graph (sdcSBM) — degree corrected (freeze \(x^+, x^-\))

```python
part_sdc, bic_sdc = detect_communities(
    nx.from_numpy_array((S != 0).astype(float)),
    S,
    mode="signed",
    degree_corrected=True,
    fix_x=True
)
```

### Weighted graph (wSBM) — geometric model

```python
W = np.random.poisson(2.0, size=(120, 120)).astype(float)
np.fill_diagonal(W, 0)
W = 0.5 * (W + W.T)

Gw = nx.from_numpy_array(W)
part_w, bic_w = detect_communities(Gw, W, mode="weighted", degree_corrected=False)
```

### Weighted graph (wdcSBM) — degree corrected (freeze \(x\))

```python
part_wdc, bic_wdc = detect_communities(
    Gw, W,
    mode="weighted",
    degree_corrected=True,
    fix_x=True
)
```

### Plot / summarize with `process_graph(...)`

```python
from domino.represent_and_analyze import process_graph

# Option A: compute a Kamada-Kawai layout (spring embedding)
pos = process_graph(
    G=Gw,
    detected_labels=part_w,     # a Partition or an array of labels
    layout_type="kamada",
    print_info=True             # prints basic stats
)

# Option B: provide your own coordinates (custom)
pos = {n: (float(n % 10), float(n // 10)) for n in Gw.nodes()}
process_graph(
    G=Gw,
    detected_labels=part_w,
    layout_type="custom",
    pos=pos,
    print_info=False
)

# Option C: group-by-community layout (no coordinates)
process_graph(
    G=Gw,
    detected_labels=part_w,
    layout_type=None,           # communities plotted in contiguous groups
    print_info=True
)
```

---

## Notes on performance and reproducibility

- Solvers are **deterministic** given inputs; randomization enters through Leiden’s shuffles/tie‑breaks, governed by `random_state` (forwarded where applicable).  
- Degree‑corrected pipelines with `fix_x=True` are typically **faster** and very stable; setting `fix_x=False` re‑fits node factors each outer loop (more accurate on some datasets, but slower).  
- Numba thread count respects the `THREADS` environment variable (default: all available cores).

---

*End of file.*