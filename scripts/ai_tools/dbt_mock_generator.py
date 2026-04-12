import argparse
import sys
import os
import re
from pathlib import Path

# Adjust import path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ai_tools.llm_client import generate_content

def main():
    parser = argparse.ArgumentParser(description="Generate realistic dbt mock data via LLM")
    parser.add_argument("--model", type=str, required=True, help="Name of the dbt model (e.g., stg_users)")
    parser.add_argument("--project-dir", type=str, default="antigravity_project", help="Path to dbt project")
    
    args = parser.parse_args()
    
    # Simple prompt logic
    prompt = f"""
    You are an expert dbt and BigQuery Data Engineer.
    Your task is to generate realistic mock data for the model: {args.model}.
    The output should be STRICTLY a CSV block. It should represent realistic data.
    Ensure data types map appropriately to BigQuery specifics (e.g., FLOAT64, INT64, TIMESTAMP) by formatting the mock values correctly (e.g., valid timestamp strings for timestamps).
    Output the CSV only, wrapped in a markdown code block (```csv).
    Generate 5-10 rows of data.
    """
    
    print(f"Generating mock data for {args.model} via Gemini...")
    response = generate_content(prompt)
    
    # Extract CSV from markdown
    csv_match = re.search(r"```csv\n(.*?)\n```", response, re.DOTALL)
    if csv_match:
        csv_data = csv_match.group(1).strip()
    else:
        # Fallback if no code block
        csv_data = response.strip()
    
    seeds_dir = Path(args.project_dir) / "seeds"
    seeds_dir.mkdir(parents=True, exist_ok=True)
    
    output_path = seeds_dir / f"mock_{args.model}.csv"
    with open(output_path, "w") as f:
        f.write(csv_data)
        
    print(f"✅ Successfully wrote mock data to {output_path}")

if __name__ == "__main__":
    main()
