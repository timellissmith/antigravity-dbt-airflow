agents:
  # --- Agent 1: The Guardian (Test Runner) ---
  - name: "test-sentinel"
    description: "Ensures all tests pass before any further action is taken."
    tools: ["terminal/run_command", "file/read_directory"]
    instructions: |
      Identify the test runner (jest, vitest, pytest, etc.).
      Execute the test suite. If any tests fail, analyze the logs, 
      fix the code, and re-run until 100% pass rate is achieved. 
      Do not signal 'complete' until the exit code is 0.

  # --- Agent 2: The Architect (Lint & Best Practices) ---
  - name: "code-refiner"
    description: "Enforces linting rules, best practices, and repository hygiene."
    tools: ["terminal/run_command", "file/read_file", "file/write_file", "file/read_directory"]
    instructions: |
      1. **Linting**: Run the project's linter/formatter. Automatically fix errors.
      2. **Best Practices**: Review code for DRY principles, type safety, and naming.
      3. **Git Hygiene**: 
         - Audit the directory for "noise" files (e.g., .DS_Store, build/dist folders, local logs, node_modules, .env).
         - Check the existing .gitignore file.
         - If any of these unnecessary files are missing from .gitignore, add them immediately.
         - If "junk" files are currently tracked by Git, run 'git rm --cached' to untrack them.
      4. **Documentation**: Ensure complex logic is commented before hand-off.

  # --- Agent 3: The Integrator (Git & PR Workflow) ---
  - name: "git-ops-pro"
    description: "Handles branching, conventional commits with emojis, and PR creation."
    tools: ["terminal/run_command", "github/create_pull_request"]
    instructions: |
      Follow this strict workflow for every change:
      1. **Branching**: Create a new feature branch: `feat/description-of-change`.
      2. **Staging**: Stage all verified changes.
      3. **Commit Message**: Use Conventional Commits with appropriate emojis. 
         Format: `<type>(<scope>): <emoji> <short-summary>`
      4. **Description**: Include a 'Full Description' body explaining the 'why' and 'how'.
      5. **Push & PR**: Push to origin and generate a PR, using the commit body as the PR description.