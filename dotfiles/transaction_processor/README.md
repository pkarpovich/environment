# Transaction Processor

Process bank transactions with AI categorization and currency conversion, with export to CSV and Google Sheets.

## Setup

### Using Fish Functions (Recommended)

1. Set up your environment variables in your Fish config:
```fish
# Add to ~/.config/fish/config.fish or your private config
set -gx OPENAI_API_KEY "your-openai-api-key"
set -gx GOOGLE_SHEETS_FILE_ID "your-sheets-file-id"
set -gx GOOGLE_CREDENTIALS_PATH "/path/to/google-credentials.json"
```

2. Process transactions:
```fish
# Use default transactions.csv
process-transactions --sheets-name "December 2024"

# Use custom input file
process-transactions my-transactions.csv --sheets-name "December 2024"

# Skip AI categorization
process-transactions --skip-categorization --sheets-name "Test Sheet"

# Custom currencies
process-transactions --currencies "USD,EUR,GBP" --sheets-name "Multi Currency"
```

### Manual Setup

1. Create virtual environment:
```bash
uv venv
uv sync
```

2. Activate environment:
```bash
source .venv/bin/activate
```

3. Run directly:
```bash
python main.py --input transactions.csv \
  --api-key YOUR_API_KEY \
  --sheets-file-id YOUR_SHEET_ID \
  --sheets-name "December 2024" \
  --google-credentials /path/to/credentials.json
```

## Environment Variables

- `OPENAI_API_KEY`: Your OpenAI API key for transaction categorization
- `GOOGLE_SHEETS_FILE_ID`: Google Sheets file ID for export
- `GOOGLE_CREDENTIALS_PATH`: Path to Google service account credentials JSON

## Arguments

- `--input`: Input CSV file (default: transactions.csv)
- `--output`: Output CSV file (default: input file with '_processed' suffix)
- `--api-key`: OpenAI API key (overrides environment variable)
- `--model`: OpenAI model to use (default: gpt-4o-mini)
- `--currencies`: Comma-separated target currencies (default: USD,EUR,PLN,BYN)
- `--skip-categorization`: Skip AI categorization
- `--sheets-file-id`: Google Sheets file ID
- `--sheets-name`: Worksheet name to create/update
- `--google-credentials`: Path to Google credentials JSON
- `--debug`: Enable debug logging

## Output Format

The processed transactions will have these columns:
- Description
- Amount (USD, Aggregated)
- Amount (EUR, Aggregated)
- Amount (PLN, Aggregated)
- Amount (BYN, Aggregated)
- Occurrences
- Category
- Comment

## Google Sheets Setup

1. Create a service account in Google Cloud Console
2. Enable Google Sheets API
3. Share your Google Sheet with the service account email
4. Use the downloaded credentials JSON file

See main.py for detailed setup instructions.