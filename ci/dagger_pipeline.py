import sys
import anyio
import dagger
from dagger import dag


async def main():
    # Initialize the Dagger client
    async with dagger.connection(dagger.Config(log_output=sys.stderr)):
        # 1. Define the project directory
        src = dag.host().directory(".")

        # Define a DuckDB profile for CI environment to avoid BQ auth issues
        # We use a file-based path to persist data between dbt invocations
        duckdb_profile = """
antigravity:
  target: ci
  outputs:
    ci:
      type: duckdb
      path: 'ci_antigravity.db'
"""

        # 2. Set up the container environment
        # We use a python image and install dbt-bigquery and pytest
        container = (
            dag.container()
            .from_("python:3.12-slim")
            .with_env_variable("PIP_NO_CACHE_DIR", "1")
            .with_exec(["apt-get", "update"])
            .with_exec(["apt-get", "install", "-y", "git", "build-essential", "libpq-dev"])
            # Install dbt-duckdb for isolated CI runs
            .with_exec(
                [
                    "pip",
                    "install",
                    "dbt-bigquery==1.11.0",
                    "dbt-duckdb==1.10.1",
                    "pytest",
                    "astronomer-cosmos",
                    "apache-airflow==2.10.5",
                ]
            )
            .with_directory("/src", src)
            .with_workdir("/src")
            # Write the CI profile
            .with_new_file("/src/ci_profiles/profiles.yml", duckdb_profile)
            # Set environment variables to override BQ specifics for DuckDB compatibility
            # The GCP_PROJECT_ID matches the DuckDB file name (without extension)
            .with_env_variable("GCP_PROJECT_ID", "ci_antigravity")
            .with_env_variable("GCP_SCHEMA", "main")
            # Airflow DAGs use these for ProfileConfig
            .with_env_variable("DBT_TARGET", "ci")
            .with_env_variable("DBT_PROFILES_YML", "/src/ci_profiles/profiles.yml")
            .with_env_variable("DBT_PROJECT_PATH", "/src/antigravity_project")
            # Set Airflow project path for Cosmos
            .with_env_variable("AIRFLOW_HOME", "/src/airflow")
            # Set CI=true for test skipping
            .with_env_variable("CI", "true")
            # Initialize Airflow DB for DagBag loading and dag.test()
            .with_exec(["airflow", "db", "migrate"])
        )

        # 3. Install dbt dependencies
        print("Installing dbt dependencies...")
        container = await container.with_exec(
            ["dbt", "deps", "--project-dir", "antigravity_project"]
        ).sync()

        # Define common dbt flags for CI
        dbt_ci_flags = "--project-dir antigravity_project --profiles-dir /src/ci_profiles --target ci"

        # 3. Install dbt dependencies
        print("Installing dbt dependencies...")
        # Switch to the project directory to ensure relative paths (seeds, etc.) work correctly
        container = container.with_workdir("/src/antigravity_project")
        await container.with_exec(["dbt", "deps"]).stdout()

        # Define common dbt flags for CI (we are now inside the project dir)
        dbt_ci_flags = "--profiles-dir /src/ci_profiles --target ci"

        try:
            # 5. Run dbt seed (Verification of data structure)
            print("Running dbt seed...")
            await container.with_exec(["dbt", "seed"] + dbt_ci_flags.split()).stdout()

            # 5.5 Run dbt unit tests
            print("Running dbt unit tests...")
            await container.with_exec(["dbt", "test", "--select", "test_type:unit"] + dbt_ci_flags.split()).stdout()

            # 6. Run dbt build (Transformation Smoke Test)
            print("Running dbt build...")
            await container.with_exec(["dbt", "build"] + dbt_ci_flags.split()).stdout()

            # 7. Run Airflow DAG tests (Pytest)
            print("Running Airflow DAG tests...")
            # We need to go back to /src for pytest
            await container.with_workdir("/src").with_exec(
                ["pytest", "-vv", "tests/test_dags.py"]
            ).stdout()

            # Final success
            print("CI/CD Pipeline Completed Successfully!")
        except dagger.ExecError as e:
            print(f"ERROR: Dagger exec failed with exit code: {e.exit_code}")
            # In 0.20.x, e.stdout and e.stderr should contain the output
            print(f"STDOUT:\n{e.stdout}")
            print(f"STDERR:\n{e.stderr}")
            sys.exit(e.exit_code)
        except Exception as e:
            print(f"ERROR: An unexpected error occurred: {type(e).__name__}: {e}")
            sys.exit(1)


if __name__ == "__main__":
    anyio.run(main)
