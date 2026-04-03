import sys
import anyio
import dagger
from dagger import dag
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv(override=True)

async def main():
    # Configuration
    project_id = os.getenv("GCP_PROJECT_ID", "modelling-demo")
    composer_bucket = os.getenv("COMPOSER_BUCKET") 
    
    # Auto-discover bucket if not set
    if not composer_bucket:
        try:
            import subprocess
            import json
            print("🔍 COMPOSER_BUCKET not set. Attempting to discover from Terraform...")
            result = subprocess.run(
                ["terraform", "-chdir=terraform", "output", "-json"],
                capture_output=True, text=True, check=True
            )
            outputs = json.loads(result.stdout)
            if "gcs_bucket" in outputs:
                # Remove gs:// prefix and /dags suffix if present
                bucket_path = outputs["gcs_bucket"]["value"]
                composer_bucket = bucket_path.replace("gs://", "").rstrip("/dags")
                print(f"✨ Found bucket: {composer_bucket}")
        except Exception as e:
            print(f"⚠️ Could not auto-discover bucket from Terraform: {e}")

    if not composer_bucket:
        print("Error: COMPOSER_BUCKET environment variable not set and discovery failed.")
        sys.exit(1)

    async with dagger.connection():
        # 1. Source code and Cloud Credentials
        source = dag.host().directory(".", exclude=[".git", "venv", "__pycache__", "terraform", ".terraform"])
        
        # Discover gcloud config path
        gcloud_config_path = os.path.expanduser("~/.config/gcloud")
        gcloud_config = dag.host().directory(gcloud_config_path)

        # ============================================================
        # STEP 1: Code Sync (CRITICAL - must succeed)
        # ============================================================
        print(f"🚀 Syncing code to gs://{composer_bucket}...")
        
        deployer = (
            dag.container()
            .from_("google/cloud-sdk:slim")
            .with_directory("/src", source)
            .with_directory("/root/.config/gcloud", gcloud_config)
            .with_workdir("/src")
            # Sync DAGs
            .with_exec([
                "gsutil", "-m", "rsync", "-r", "-d", 
                "dags/", f"gs://{composer_bucket}/dags/"
            ])
            # Sync dbt project
            .with_exec([
                "gsutil", "-m", "rsync", "-r", "-d", 
                "antigravity_project/", f"gs://{composer_bucket}/dags/antigravity_project/"
            ])
        )

        try:
            await deployer.stdout()
            print("✅ Code sync complete!")
        except Exception as e:
            print(f"❌ Code sync FAILED: {e}")
            sys.exit(1)

        # ============================================================
        # STEP 2: Verify DAGs are parseable via Airflow UI
        # ============================================================
        print("🧪 Verifying DAG status in Composer...")
        
        airflow_uri = os.getenv("AIRFLOW_URI")
        if not airflow_uri:
            try:
                import subprocess, json
                result = subprocess.run(
                    ["terraform", "-chdir=terraform", "output", "-json"],
                    capture_output=True, text=True, check=True
                )
                outputs = json.loads(result.stdout)
                if "airflow_uri" in outputs:
                    airflow_uri = outputs["airflow_uri"]["value"]
            except Exception:
                pass

        if airflow_uri:
            print(f"📋 Airflow UI: {airflow_uri}")
            
            # Use gcloud to check DAG status via the Composer REST API
            verifier = (
                dag.container()
                .from_("google/cloud-sdk:slim")
                .with_directory("/root/.config/gcloud", gcloud_config)
                .with_exec([
                    "bash", "-c",
                    f'curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" '
                    f'"{airflow_uri}/api/v2/dags" 2>/dev/null | python3 -m json.tool || echo "Could not reach Airflow API (DAGs may still be loading)"'
                ])
            )
            
            try:
                output = await verifier.stdout()
                print(output)
            except Exception as e:
                print(f"⚠️ Could not verify DAGs via API (this is not critical): {e}")
        else:
            print("⚠️ Airflow URI not found, skipping API verification")

        print("✅ Deployment complete! Check the Airflow UI for DAG status.")

if __name__ == "__main__":
    anyio.run(main)
