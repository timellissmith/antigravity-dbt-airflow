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
        duckdb_profile = """
antigravity:
  target: ci
  outputs:
    ci:
      type: duckdb
      path: '/src/ci_antigravity.db'
"""

        # 2. Set up the container environment
        container = (
            dag.container()
            .from_("python:3.13-slim")
            .with_env_variable("PIP_NO_CACHE_DIR", "1")
            .with_exec(["apt-get", "update"])
            .with_exec(["apt-get", "install", "-y", "git", "curl", "build-essential", "libpq-dev", "jq"])
            .with_exec(
                [
                    "pip",
                    "install",
                    "dbt-bigquery==1.11.0",
                    "dbt-duckdb==1.10.1",
                    "pytest",
                    "astronomer-cosmos",
                    "apache-airflow==3.1.8",
                ]
            )
            .with_directory("/src", src)
            .with_workdir("/src")
            .with_new_file("/src/ci_profiles/profiles.yml", duckdb_profile)
            .with_env_variable("GCP_PROJECT_ID", "ci_antigravity")
            .with_env_variable("GCP_SCHEMA", "main")
            .with_env_variable("DBT_TARGET", "ci")
            .with_env_variable("DBT_PROFILES_YML", "/src/ci_profiles/profiles.yml")
            .with_env_variable("DBT_PROJECT_PATH", "/src/antigravity_project")
            .with_env_variable("AIRFLOW_HOME", "/src/airflow")
            .with_env_variable("AIRFLOW__CORE__DAGS_FOLDER", "/src/dags")
            .with_env_variable("PATH", "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin")
            .with_env_variable("SHELL", "/bin/bash")
            .with_exec(["bash", "-c", "curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | bash -s -- --update"])
            .with_exec(["ln", "-s", "/root/.local/bin/dbt", "/usr/local/bin/dbtf"])
            .with_exec(["airflow", "db", "migrate"])
        )

        # Define common dbt flags for CI
        dbt_ci_flags = "--project-dir antigravity_project --profiles-dir /src/ci_profiles --target ci"

        try:
            # 4. Install dbt dependencies
            print("Installing dbt dependencies using dbt-fusion...")
            container = await container.with_exec(["dbtf", "deps", "--project-dir", "antigravity_project"]).sync()
            # 5. Run dbt-fusion seed (Verification of data structure)
            print("Running dbt-fusion seed...")
            container = await container.with_exec(["dbtf", "seed"] + dbt_ci_flags.split()).sync()

            # 6. Run dbt-fusion models (Ensure relations exist for unit test introspection)
            print("Running dbt-fusion models (Silver/Gold)...")
            container = await container.with_exec(["dbtf", "run"] + dbt_ci_flags.split()).sync()

            # 7. Run dbt-fusion unit tests
            print("Running dbt-fusion unit tests...")
            container = await container.with_exec(["dbtf", "test", "--select", "test_type:unit"] + dbt_ci_flags.split()).sync()

            # 8. Run dbt-fusion generic tests
            print("Running dbt-fusion generic tests...")
            container = await container.with_exec(["dbtf", "test", "--exclude", "test_type:unit"] + dbt_ci_flags.split()).sync()

            # 9. Run Airflow DAG tests (Pytest)
            print("Running Airflow DAG tests...")
            # Airflow 3 requires DAG reserialization for dag.test() execution
            await container.with_exec(["airflow", "dags", "reserialize"]).stdout()
            await container.with_exec(
                ["pytest", "-vv", "tests/test_dags.py"]
            ).stdout()

            # Final success
            print("CI/CD Pipeline Completed Successfully!")
        except dagger.ExecError as e:
            print(f"ERROR: Dagger exec failed with exit code: {e.exit_code}")
            print(f"STDOUT:\n{e.stdout}")
            print(f"STDERR:\n{e.stderr}")
            sys.exit(e.exit_code)
        except Exception as e:
            print(f"ERROR: An unexpected error occurred: {type(e).__name__}: {e}")
            sys.exit(1)


if __name__ == "__main__":
    anyio.run(main)
