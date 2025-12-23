# Mathematical background

This note summarizes the likelihoods and BIC expressions used by DOMINO.

Let $N$ be the number of nodes, $B$ the number of blocks, and $c_i \in \{1,\dots,B\}$
the block label of node $i$. For each pair of blocks $(r,s)$, define:

- $L_{rs}$, the number of observed edges between $r$ and $s$,
- $M_{rs}$, the number of possible dyads between $r$ and $s$.

For undirected graphs,

$$
M_{rs} =
\begin{cases}
n_r n_s, & r \neq s, \\
\frac{n_r (n_r - 1)}{2}, & r = s.
\end{cases}
$$

## Binary SBM

Parameters are block probabilities $p_{rs} \in (0,1)$. The log-likelihood is

$$
\log L
= \sum_{r \le s}
\Big[
L_{rs} \log p_{rs} + (M_{rs} - L_{rs}) \log(1 - p_{rs})
\Big].
$$

## Degree-corrected binary SBM

A typical parameterization uses node factors $x_i > 0$ and block affinities $\chi_{rs} > 0$,
leading to

$$
p_{ij} = \frac{x_i x_j \chi_{c_i c_j}}{1 + x_i x_j \chi_{c_i c_j}}.
$$

The Bernoulli log-likelihood is

$$
\log L = \sum_{i<j}\Big[ A_{ij}\log p_{ij} + (1-A_{ij})\log(1-p_{ij}) \Big].
$$

## Signed SBM

Each dyad can be positive, negative, or absent. For each block pair, define
$L^+_{rs}$, $L^-_{rs}$, and $L^0_{rs}$, with $L^0_{rs} = M_{rs} - L^+_{rs} - L^-_{rs}$.
The maximum-likelihood block probabilities are

$$
\begin{aligned}
p^+_{rs} &= \frac{L^+_{rs}}{M_{rs}}, \\
p^-_{rs} &= \frac{L^-_{rs}}{M_{rs}}, \\
p^0_{rs} &= 1 - p^+_{rs} - p^-_{rs}.
\end{aligned}
$$

The log-likelihood is

$$
\log L
= \sum_{r \le s}
\Big[
L^+_{rs}\log p^+_{rs}
+ L^-_{rs}\log p^-_{rs}
+ L^0_{rs}\log p^0_{rs}
\Big].
$$

## Signed degree-corrected SBM

A convenient parameterization introduces positive and negative node factors
$(x_i^+, x_i^-)$ and block affinities $(\chi^+_{rs}, \chi^-_{rs})$. One obtains

$$
\begin{aligned}
p^+_{ij} &=
\frac{x_i^+ x_j^+ \chi^+_{c_i c_j}}
{1 + x_i^+ x_j^+ \chi^+_{c_i c_j} + x_i^- x_j^- \chi^-_{c_i c_j}}, \\
p^-_{ij} &=
\frac{x_i^- x_j^- \chi^-_{c_i c_j}}
{1 + x_i^+ x_j^+ \chi^+_{c_i c_j} + x_i^- x_j^- \chi^-_{c_i c_j}}.
\end{aligned}
$$

and $p^0_{ij} = 1 - p^+_{ij} - p^-_{ij}$.

## Weighted SBM, geometric weights

For nonnegative weights $w_{ij}$, a common choice is a geometric distribution
parameterized by a mean $z_{ij} > 0$, with block means $z_{rs}$.
At block level, the geometric log-likelihood can be written as

$$
\log L
= \sum_{r \le s}
\Big[
W_{rs}\log z_{rs} - (W_{rs} + M_{rs})\log(1+z_{rs})
\Big],
$$

where $W_{rs}$ is the total weight between blocks $r$ and $s$.

## Weighted degree-corrected SBM

A standard factorization uses

$$
z_{ij} = x_i x_j \chi_{c_i c_j},
$$

and the corresponding dyad log-likelihood is

$$
\log L
= \sum_{i<j}\Big[ w_{ij}\log z_{ij} - (w_{ij}+1)\log(1+z_{ij}) \Big].
$$

## Bayesian Information Criterion

The Bayesian information criterion is

$$
\mathrm{BIC} = k \log V - 2\log L,
$$

where $V = N(N-1)/2$ is the number of potential dyads and $k$ is the number of
free parameters.

Typical parameter counts:

- SBM: $k = B(B+1)/2$
- dcSBM: $k = N + B(B+1)/2$
- Signed SBM: $k = B(B+1)$
- Signed dcSBM: $k = 2N + B(B+1)$
- Weighted SBM: $k = B(B+1)/2$
- Weighted dcSBM: $k = N + B(B+1)/2$