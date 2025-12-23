"""tests/conftest.py

Shared fixtures and helper functions for the DOMINO test suite.

The utilities in this module generate small synthetic networks with a clear
mesoscale signal while avoiding trivial disconnected block structures.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple

import numpy as np
import networkx as nx


@dataclass(frozen=True)
class SyntheticInstance:
    """Container for a synthetic network instance."""

    A: np.ndarray
    G: nx.Graph
    labels: np.ndarray


def _make_block_labels(n: int, block_sizes: Tuple[int, ...]) -> np.ndarray:
    """Create a deterministic block assignment vector of length n."""
    if sum(block_sizes) != n:
        raise ValueError("block_sizes must sum to n")
    labels = np.empty(n, dtype=int)
    start = 0
    for r, sz in enumerate(block_sizes):
        labels[start : start + sz] = r
        start += sz
    return labels


def _ensure_connected_binary(A: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Ensure connectivity by adding a sparse set of bridging edges."""
    G = nx.from_numpy_array((A > 0).astype(int))
    if nx.is_connected(G):
        return A

    A2 = A.copy()
    comps = [list(c) for c in nx.connected_components(G)]
    reps = [c[rng.integers(0, len(c))] for c in comps]
    for u, v in zip(reps[:-1], reps[1:]):
        A2[u, v] = 1
        A2[v, u] = 1
    np.fill_diagonal(A2, 0)
    return A2


def _ensure_connected_weighted(W: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Ensure connectivity by adding small positive bridging weights."""
    G = nx.from_numpy_array((W > 0).astype(int))
    if nx.is_connected(G):
        return W

    W2 = W.copy()
    comps = [list(c) for c in nx.connected_components(G)]
    reps = [c[rng.integers(0, len(c))] for c in comps]
    for u, v in zip(reps[:-1], reps[1:]):
        W2[u, v] = max(W2[u, v], 1.0)
        W2[v, u] = max(W2[v, u], 1.0)
    np.fill_diagonal(W2, 0.0)
    return W2


def sbm_binary(
    *,
    n: int = 100,
    block_sizes: Tuple[int, ...] = (34, 33, 33),
    p_in: float = 0.25,
    p_out: float = 0.03,
    seed: int = 12345,
) -> SyntheticInstance:
    """Generate an undirected binary SBM instance with mild but clear structure."""
    rng = np.random.default_rng(seed)
    labels = _make_block_labels(n, block_sizes)
    A = np.zeros((n, n), dtype=int)

    for i in range(n):
        for j in range(i + 1, n):
            pij = p_in if labels[i] == labels[j] else p_out
            if rng.random() < pij:
                A[i, j] = 1
                A[j, i] = 1

    np.fill_diagonal(A, 0)
    A = _ensure_connected_binary(A, rng)
    G = nx.from_numpy_array(A)
    return SyntheticInstance(A=A, G=G, labels=labels)


def sbm_signed(
    *,
    n: int = 100,
    block_sizes: Tuple[int, ...] = (50, 50),
    p_pos_in: float = 0.22,
    p_neg_out: float = 0.18,
    p_pos_out: float = 0.03,
    seed: int = 24680,
) -> SyntheticInstance:
    """Generate a signed SBM-like instance with positive within-block and negative between-block edges."""
    rng = np.random.default_rng(seed)
    labels = _make_block_labels(n, block_sizes)
    A = np.zeros((n, n), dtype=float)

    for i in range(n):
        for j in range(i + 1, n):
            if labels[i] == labels[j]:
                if rng.random() < p_pos_in:
                    A[i, j] = 1.0
                    A[j, i] = 1.0
            else:
                r = rng.random()
                if r < p_neg_out:
                    A[i, j] = -1.0
                    A[j, i] = -1.0
                elif r < p_neg_out + p_pos_out:
                    A[i, j] = 1.0
                    A[j, i] = 1.0

    np.fill_diagonal(A, 0.0)

    # Connectivity is assessed on the union support (|A|>0).
    Abin = (np.abs(A) > 0).astype(int)
    Abin = _ensure_connected_binary(Abin, rng)
    # If we added bridging edges, make them positive to avoid destabilizing sign structure.
    bridged = (Abin > 0) & (np.abs(A) == 0)
    A[bridged] = 1.0
    A = 0.5 * (A + A.T)
    np.fill_diagonal(A, 0.0)

    if not np.any(A < 0):
        # Guarantee at least one negative edge, which is required by mode="signed".
        i = 0
        j = n - 1
        if labels[i] == labels[j]:
            j = n // 2
        A[i, j] = -1.0
        A[j, i] = -1.0

    G = nx.from_numpy_array((np.abs(A) > 0).astype(int))
    return SyntheticInstance(A=A, G=G, labels=labels)


def sbm_weighted(
    *,
    n: int = 100,
    block_sizes: Tuple[int, ...] = (34, 33, 33),
    p_in: float = 0.22,
    p_out: float = 0.04,
    lam_in: float = 4.0,
    lam_out: float = 1.0,
    seed: int = 9876,
) -> SyntheticInstance:
    """Generate a nonnegative weighted SBM instance with integer weights."""
    rng = np.random.default_rng(seed)
    labels = _make_block_labels(n, block_sizes)
    W = np.zeros((n, n), dtype=float)

    for i in range(n):
        for j in range(i + 1, n):
            pij = p_in if labels[i] == labels[j] else p_out
            if rng.random() < pij:
                lam = lam_in if labels[i] == labels[j] else lam_out
                w = float(rng.poisson(lam))
                if w <= 0.0:
                    w = 1.0
                W[i, j] = w
                W[j, i] = w

    np.fill_diagonal(W, 0.0)
    W = _ensure_connected_weighted(W, rng)
    G = nx.from_numpy_array((W > 0).astype(int))
    return SyntheticInstance(A=W, G=G, labels=labels)
