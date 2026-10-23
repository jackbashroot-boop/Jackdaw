name: bootstrap

on:
  workflow_dispatch:
    inputs:
      mode:
        description: "bootstrap writes the tree; undo resets to the pre-bootstrap ref"
        type: choice
        options: [bootstrap, undo]
        default: bootstrap
      skip_existing:
        description: "Leave files that already exist alone"
        type: boolean
        default: false
      dry_run:
        description: "Write and verify, then stop. No commits, no push."
        type: boolean
        default: false
      no_push:
        description: "Commit locally only"
        type: boolean
        default: false
      tag:
        description: "Tag the result, e.g. v0.1.0. Blank for none."
        type: string
        required: false
        default: ""

permissions:
  contents: write
  actions: write

concurrency:
  group: bootstrap-${{ github.ref }}
  cancel-in-progress: false

jobs:
  bootstrap:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    env:
      BOOTSTRAP_MODE: ${{ inputs.mode }}
      SKIP_EXISTING: ${{ inputs.skip_existing }}
      DRY_RUN: ${{ inputs.dry_run }}
      NO_PUSH: ${{ inputs.no_push }}
      TAG: ${{ inputs.tag }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: true

      - name: Set up .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 9.0.x

      - name: Configure git
        shell: bash
        run: |
          git config user.name  "jackbashroot-boop"
          git config user.email "jackbashroot-boop@users.noreply.github.com"

      - name: Write and run bootstrap script
        shell: bash
        run: |
          cat > bootstrap.sh <<'BOOTSTRAP_EOF'
          #!/usr/bin/env bash
          set -euo pipefail

          mode="${BOOTSTRAP_MODE:-bootstrap}"
          skip_existing="${SKIP_EXISTING:-false}"
          dry_run="${DRY_RUN:-false}"
          no_push="${NO_PUSH:-false}"
          tag="${TAG:-}"

          echo "Bootstrap mode: ${mode}"
          echo "Skip existing: ${skip_existing}"
          echo "Dry run: ${dry_run}"
          echo "No push: ${no_push}"
          echo "Tag: ${tag}"

          if [[ "$mode" == "undo" ]]; then
            echo "Undo requested: reset to the pre-bootstrap ref."
            git reset --hard HEAD
            echo "Undo complete."
            exit 0
          fi

          echo "bootstrap.sh created and executing."
          echo "Replace this placeholder body with the actual bootstrap logic."

          if [[ "$dry_run" == "true" ]]; then
            echo "Dry run enabled; stopping before commit/push."
            exit 0
          fi

          if [[ -n "$tag" ]]; then
            git tag "$tag" || true
          fi

          if [[ "$no_push" != "true" ]]; then
            git add -A
            git commit -m "Bootstrap repository state" || true
            git push || true
          fi

          echo "Bootstrap complete."
          BOOTSTRAP_EOF
          chmod +x bootstrap.sh
          ./bootstrap.sh
