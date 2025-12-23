# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and the project follows Semantic Versioning.

## [Unreleased]
### Added
- Development dependencies via `.[dev]`.
- CI checks: ruff linting, formatting check, pytest, and build validation.

## [0.1.0] - 2025-12-23
### Added
- Public API entry point `detect` for BIC-based community detection.
- Support for `mode="binary"`, `mode="signed"`, and `mode="weighted"`.
- Non degree-corrected and degree-corrected model families (SBM and extensions).
- Initial test suite on small synthetic graphs (binary, signed, weighted).
- GitHub Actions CI running tests on Python 3.10, 3.11, and 3.12.
