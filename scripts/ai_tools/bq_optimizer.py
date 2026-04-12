import argparse
import sys
import os
import re
from pathlib import Path

# Adjust import path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ai_tools.llm_client import generate_content

def main():
    parser = argparse.ArgumentParser(description="Optimize dbt BigQuery models via LLM")
    parser.add_argument("--model-path", type=str, required=True, help="Path to the .sql model file")
    
    args = parser.parse_args()
    model_path = Path(args.model_path)
    
    if not model_path.exists():
        print(f"ERROR: Model file not found at {model_path}", file=sys.stderr)
        sys.exit(1)
        
    with open(model_path, "r") as f:
        original_sql = f.read()
    
    prompt = f"""
    You are an expert dbt and BigQuery Performance Engineer.
    Your task is to analyze the following dbt model SQL and suggest optimizations.
    Specifically look for:
    1. Partitioning and clustering opportunities (e.g., using `partition_by` and `cluster_by` in the config block) Let's assume there is a timestamp column if it looks like timeseries data.
    2. Join optimizations.
    
    Here is the SQL:
    ```sql
    {original_sql}
    ```
    
    Output the fully optimized dbt model SQL, wrapped in a markdown code block (```sql). 
    Ensure it retains its dbt jinja logic, but with the necessary config blocks and optimization updates.
    """
    
    print(f"Optimizing {model_path.name} via Gemini...")
    response = generate_content(prompt)
    
    # Extract SQL from markdown
    sql_match = re.search(r"```sql\n(.*?)\n```", response, re.DOTALL)
    if sql_match:
        optimized_sql = sql_match.group(1).strip()
    else:
        # Fallback if no code block
        optimized_sql = response.strip()
    
    with open(model_path, "w") as f:
        f.write(optimized_sql)
        
    print(f"✅ Successfully rewrote {model_path} with BigQuery optimizations.")

if __name__ == "__main__":
    main()
