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
        run: |
          git config user.name  "jackbashroot-boop"
          git config user.email "jackbashroot-boop@users.noreply.github.com"

      - name: Seed bootstrap.sh
        run: |
          cat > bootstrap.sh <<'BOOTSTRAP_EOF'
          #!/usr/bin/env bash
          set -euo pipefail

          echo "bootstrap.sh created"
          echo "This is the placeholder script. Replace with the full bootstrap script if needed."
          BOOTSTRAP_EOF
          chmod +x bootstrap.sh
