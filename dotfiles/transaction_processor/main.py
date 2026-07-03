import argparse
import asyncio
import json
import logging
import re
import sys
import time
from collections import defaultdict
from csv import DictReader, DictWriter
from enum import Enum
from typing import Annotated
import httpx

from openai import AsyncOpenAI
from pydantic import BaseModel, Field, field_validator
from google.auth.transport.requests import Request
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)-8s | %(message)s',
    datefmt='%H:%M:%S',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

DEFAULT_MODEL = "gpt-4o-mini"
DEFAULT_OUTPUT_SUFFIX = "_processed.csv"
DEFAULT_CURRENCIES = ["USD", "EUR", "PLN", "BYN"]

Currency = Annotated[str, Field(min_length=3, max_length=3, description="ISO currency code")]
TransactionDate = Annotated[str, Field(description="Transaction date")]

class TransactionType(str, Enum):
    CARD_PAYMENT = "CARD_PAYMENT"
    TRANSFER = "TRANSFER"
    PAYMENT = "PAYMENT"
    CASH_WITHDRAWAL = "CASH_WITHDRAWAL"
    DEPOSIT = "DEPOSIT"

class TransactionState(str, Enum):
    COMPLETED = "COMPLETED"
    PENDING = "PENDING"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"

CATEGORIZATION_PROMPT = """
Categorize these transactions based on their descriptions:

Categories to use:
- Electronic payments & donations (PaySend, DonationAlerts, PayPal, money transfers)
- Food & delivery (Glovo, Uber Eats, food delivery services, restaurants)
- Subscriptions & digital services (YouTube, Spotify, Netflix, OpenAI, Patreon, Viaplay, Toggl, streaming)
- Groceries & household goods (Auchan, supermarkets, grocery stores, household items)
- Entertainment (Cinema, games, entertainment venues, leisure activities)
- Cashback & bonuses (any cashback, rewards, or bonus payments)
- Cash withdrawals (ATM withdrawals, cash operations)
- Mobile & internet services (T-Mobile, Netia, telecom, internet providers)
- Tools & development (JetBrains, GitHub, Midjourney, Figma, CleanShot, Nylas, development tools)
- Transport (Uber, taxi, public transport, travel)
- Healthcare & wellness (medical, pharmacy, health services)
- Shopping & retail (clothing, electronics, general retail)
- Miscellaneous (anything that doesn't fit other categories)

For each transaction, update the "category" field with the most appropriate category.
Return a JSON array with the same structure but with filled category fields.
"""

class TransactionRow(BaseModel):
    type: str
    product: str
    started_date: TransactionDate
    completed_date: TransactionDate
    description: str
    amount: Annotated[float, Field(description="Transaction amount")]
    fee: Annotated[float, Field(ge=0, description="Non-negative fee amount")]
    currency: Currency
    state: str
    balance: Annotated[float, Field(description="Account balance")]
    occurrences: Annotated[int, Field(ge=1, description="Number of occurrences")]
    
    @field_validator('amount', 'fee', 'balance', mode='before')
    @classmethod
    def empty_to_zero(cls, v):
        if v == '' or v is None:
            return 0.0
        return v

class Transactions(BaseModel):
    transactions: list[TransactionRow] = Field(..., description="List of transaction rows", default_factory=list)

class SimplifiedTransaction(BaseModel):
    description: str
    category: str

class CategorizedTransactions(BaseModel):
    transactions: list[SimplifiedTransaction] = Field(..., description="List of categorized transactions", default_factory=list)


class GroupedTransaction(BaseModel):
    description: str
    amounts: dict[Currency, float] = Field(default_factory=dict, description="Original currency amounts")
    converted_amounts: dict[Currency, float] = Field(default_factory=dict, description="Amounts converted to all currencies")
    occurrences: Annotated[int, Field(ge=1, description="Number of grouped transactions")]
    category: str = Field(default="", description="Transaction category")
    comment: str = Field(default="", description="Additional comment")

def is_internal_transfer(transaction: TransactionRow) -> bool:
    """
    Detect internal transfers using multiple signals instead of hardcoded text.
    
    Internal transfers have these characteristics:
    1. Type is 'TRANSFER' or 'EXCHANGE'
    2. Description follows patterns: 'To [CURRENCY] [Savings]', 'Exchange to [CURRENCY]'
    3. Zero fee for transfers (internal transfers don't have fees)
    4. Specific patterns in description
    """
    
    # Rule 1: EXCHANGE operations are always internal
    if transaction.type == "EXCHANGE":
        return True
    
    # Rule 2: Must be a TRANSFER type for other internal operations
    if transaction.type != "TRANSFER":
        return False
    
    # Rule 3: Pattern matching for internal transfer descriptions
    internal_patterns = [
        r'^To\s+[A-Z]{3}(\s+Savings)?(\s+[A-Z]{3})?$',  # "To PLN", "To PLN Savings", "To EUR Savings EUR"
        r'^Exchange\s+to\s+[A-Z]{3}$',  # "Exchange to PLN"
    ]
    
    description = transaction.description.strip()
    
    for pattern in internal_patterns:
        if re.match(pattern, description, re.IGNORECASE):
            return True
    
    # Rule 4: Additional keywords that indicate internal transfers
    internal_keywords = ['savings', 'pocket', 'vault', 'goals']
    description_lower = description.lower()
    if any(keyword in description_lower for keyword in internal_keywords):
        return True
    
    # Rule 5: Check for transfers between user's own currency accounts
    # Pattern: "To [CURRENCY]" without "Savings" might still be internal
    if re.match(r'^To\s+[A-Z]{3}$', description):
        return True
    
    # Rule 6: Transfers from/to other users are external
    if 'Transfer from Revolut user' in description or 'Transfer to' in description:
        return False
    
    return False


def read_transactions_from_csv(filepath: str) -> list[TransactionRow]:
    transactions = []

    with open(filepath, 'r', encoding='utf-8') as f:
        reader = DictReader(f)
        for row in reader:
            transaction = TransactionRow(
                type=row.get('Type', ''),
                product=row.get('Product', ''),
                started_date=row.get('Started Date', ''),
                completed_date=row.get('Completed Date', ''),
                description=row.get('Description', ''),
                amount=row.get('Amount', 0.0),
                fee=row.get('Fee', 0.0),
                currency=row.get('Currency', ''),
                state=row.get('State', ''),
                balance=row.get('Balance', 0.0),
                occurrences=1
            )
            transactions.append(transaction)

    logger.debug(f"Loaded {len(transactions)} transactions from {filepath}")
    return transactions


def filter_external_transactions(transactions: list[TransactionRow]) -> list[TransactionRow]:
    """Filter out internal transfers and keep only external transactions."""
    external_transactions = []
    internal_count = 0
    
    for transaction in transactions:
        if transaction.state != "COMPLETED":
            continue
            
        if is_internal_transfer(transaction):
            internal_count += 1
            logger.debug(f"Filtered internal transfer: {transaction.description} ({transaction.currency} {transaction.amount})")
        else:
            external_transactions.append(transaction)
    
    logger.info(f"Filtered {internal_count} internal transfers, kept {len(external_transactions)} external transactions")
    return external_transactions


def group_transactions_by_description(transactions: list[TransactionRow]) -> list[GroupedTransaction]:
    grouped = defaultdict(list)

    for transaction in transactions:
        grouped[transaction.description].append(transaction)

    result = []
    for description, group in grouped.items():
        amounts_by_currency = defaultdict(float)
        for transaction in group:
            amounts_by_currency[transaction.currency] += transaction.amount

        grouped_transaction = GroupedTransaction(
            description=description,
            amounts=dict(amounts_by_currency),
            occurrences=len(group),
            category="",
            comment=""
        )

        result.append(grouped_transaction)

    logger.debug(f"Grouped {len(transactions)} transactions into {len(result)} unique groups")
    return result


async def get_exchange_rates(base_currency: str = "USD") -> dict[str, float]:
    """Fetch current exchange rates from ExchangeRate-API."""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"https://api.exchangerate-api.com/v4/latest/{base_currency}")
            response.raise_for_status()
            data = response.json()
            rates = {currency: float(rate) for currency, rate in data["rates"].items()}
            logger.debug(f"Fetched exchange rates for {len(rates)} currencies")
            return rates
    except Exception as e:
        logger.error(f"Failed to fetch exchange rates: {e}")
        return {}


async def categorize_transactions(grouped_transactions: list[GroupedTransaction], openai_client: AsyncOpenAI, model: str) -> list[GroupedTransaction]:
    """Categorize transactions using AI based on their descriptions."""
    logger.info("🏷️ Categorizing transactions...")
    initial_count = len(grouped_transactions)

    simplified_transactions = [
        {"description": t.description, "category": ""} 
        for t in grouped_transactions
    ]
    transactions_json = json.dumps(simplified_transactions, ensure_ascii=False)

    response = await openai_client.responses.parse(
        model=model,
        instructions=CATEGORIZATION_PROMPT,
        input=transactions_json,
        temperature=0.0,
        text_format=CategorizedTransactions,
    )

    categorized_results = response.output_parsed or []
    
    if len(categorized_results.transactions) != initial_count:
        logger.warning(f"⚠️  Count mismatch: sent {initial_count} transactions, received {len(categorized_results.transactions)} categorized")
    
    category_map = {t.description: t.category for t in categorized_results.transactions}
    missing_descriptions = []
    
    for transaction in grouped_transactions:
        if transaction.description in category_map:
            transaction.category = category_map[transaction.description]
        else:
            transaction.category = "Miscellaneous"
            missing_descriptions.append(transaction.description)
    
    if missing_descriptions:
        logger.warning(f"⚠️  {len(missing_descriptions)} transactions not found in AI response, defaulted to 'Miscellaneous'")
    
    final_count = len(grouped_transactions)
    if final_count != initial_count:
        logger.error(f"❌ Transaction count changed during categorization: {initial_count} → {final_count}")
    else:
        logger.info(f"✅ Successfully categorized {len(grouped_transactions)} transactions")
    
    return grouped_transactions


async def convert_currency_amounts(grouped_transactions: list[GroupedTransaction], target_currencies: list[str]) -> list[GroupedTransaction]:
    """Convert all transaction amounts to target currencies."""
    usd_rates = await get_exchange_rates("USD")
    
    for transaction in grouped_transactions:
        total_usd = 0.0
        for currency, amount in transaction.amounts.items():
            if currency == "USD":
                total_usd += amount
            else:
                rate_to_usd = 1.0 / usd_rates.get(currency, 1.0)  # 1 / rate because we need USD per foreign currency
                total_usd += amount * rate_to_usd
        
        converted_amounts = {}
        for target_currency in target_currencies:
            if target_currency == "USD":
                converted_amounts[target_currency] = round(total_usd, 2)
            else:
                rate = usd_rates.get(target_currency, 1.0)
                converted_amounts[target_currency] = round(total_usd * rate, 2)
        
        transaction.converted_amounts = converted_amounts
    
    return grouped_transactions


def _prepare_export_data(grouped_transactions: list[GroupedTransaction]) -> tuple[list[dict], list[str]]:
    """Prepare export data with flattened structure for both CSV and Sheets export."""
    rows = []
    for transaction in grouped_transactions:
        row = {
            'Description': transaction.description,
            'Category': transaction.category,
            'Occurrences': transaction.occurrences,
            'Comment': transaction.comment,
        }
        
        # Add only converted amounts with user-friendly names
        for currency, amount in transaction.converted_amounts.items():
            row[f'Amount ({currency}, Aggregated)'] = round(amount, 2)
        
        rows.append(row)
    
    # Get all unique field names with specific ordering
    fieldnames = []
    if rows:
        # Define the order of fields
        base_fields = ['Description', 'Category', 'Occurrences', 'Comment']
        
        # Collect all unique amount fields from ALL rows
        all_amount_fields = set()
        
        for row in rows:
            all_amount_fields.update([k for k in row.keys() if k.startswith('Amount (')])
        
        # Sort the amount fields
        amount_fields = sorted(list(all_amount_fields))
        
        # Combine in logical order: Description, Amount fields, Occurrences, Category, Comment
        # Reorder to match user's requested format
        fieldnames = ['Description']
        fieldnames.extend(amount_fields)
        fieldnames.extend(['Occurrences', 'Category', 'Comment'])
        
        # Ensure all rows have all fields (fill missing with empty string)
        for row in rows:
            for field in fieldnames:
                if field not in row:
                    row[field] = ''
    
    return rows, fieldnames


def export_to_csv(grouped_transactions: list[GroupedTransaction], output_path: str):
    """Export grouped transactions to CSV with flattened structure."""
    logger.info(f"💾 Exporting results to {output_path}...")
    
    rows, fieldnames = _prepare_export_data(grouped_transactions)
    
    if rows:
        # Write CSV
        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        
        logger.info(f"✅ Successfully exported {len(rows)} transactions to {output_path}")
    else:
        logger.warning("⚠️  No transactions to export")


def export_to_sheets(grouped_transactions: list[GroupedTransaction], file_id: str, sheet_name: str, credentials_path: str):
    """Export grouped transactions to Google Sheets."""
    logger.info(f"📊 Exporting results to Google Sheets: {sheet_name}...")
    
    try:
        # Authenticate with Google Sheets API
        creds = Credentials.from_service_account_file(
            credentials_path,
            scopes=['https://www.googleapis.com/auth/spreadsheets']
        )
        service = build('sheets', 'v4', credentials=creds, cache_discovery=False)
        
        # Prepare data
        rows, fieldnames = _prepare_export_data(grouped_transactions)
        
        if not rows:
            logger.warning("⚠️  No transactions to export to Sheets")
            return
        
        # Convert data to list of lists for Sheets API
        header_row = [fieldnames]
        data_rows = [[row.get(field, '') for field in fieldnames] for row in rows]
        values = header_row + data_rows
        
        # Check if sheet exists, create if it doesn't
        spreadsheet = service.spreadsheets().get(spreadsheetId=file_id).execute()
        sheet_exists = any(sheet['properties']['title'] == sheet_name for sheet in spreadsheet['sheets'])
        
        if not sheet_exists:
            # Create new sheet
            request_body = {
                'requests': [{
                    'addSheet': {
                        'properties': {
                            'title': sheet_name
                        }
                    }
                }]
            }
            service.spreadsheets().batchUpdate(spreadsheetId=file_id, body=request_body).execute()
            logger.info(f"📋 Created new sheet: {sheet_name}")
        else:
            # Clear existing data
            range_name = f"{sheet_name}!A:ZZ"
            service.spreadsheets().values().clear(
                spreadsheetId=file_id,
                range=range_name
            ).execute()
            logger.info(f"🧹 Cleared existing data in sheet: {sheet_name}")
        
        # Write data to sheet
        range_name = f"{sheet_name}!A1"
        body = {
            'values': values,
            'majorDimension': 'ROWS'
        }
        
        service.spreadsheets().values().update(
            spreadsheetId=file_id,
            range=range_name,
            valueInputOption='RAW',
            body=body
        ).execute()
        
        logger.info(f"✅ Successfully exported {len(rows)} transactions to Google Sheets: {sheet_name}")
        
    except Exception as e:
        logger.error(f"❌ Failed to export to Google Sheets: {e}")
        raise


def parse_arguments():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Process bank transactions with AI categorization and currency conversion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --input transactions.csv --api-key YOUR_API_KEY
  %(prog)s --input data.csv --model gpt-4o --currencies USD,EUR,PLN
  %(prog)s --input transactions.csv --api-key YOUR_API_KEY --output processed_transactions.csv
        """
    )
    
    parser.add_argument(
        "--input",
        type=str,
        required=True,
        help="Path to input CSV file with transactions"
    )
    
    parser.add_argument(
        "--output",
        type=str,
        help="Path to output CSV file (default: input file with '_processed' suffix)"
    )
    
    parser.add_argument(
        "--api-key",
        type=str,
        help="OpenAI API key for transaction categorization (required unless --skip-categorization is used)"
    )
    
    parser.add_argument(
        "--model",
        type=str,
        default=DEFAULT_MODEL,
        help=f"OpenAI model to use for categorization (default: {DEFAULT_MODEL})"
    )
    
    parser.add_argument(
        "--currencies",
        type=str,
        default=",".join(DEFAULT_CURRENCIES),
        help=f"Comma-separated list of target currencies (default: {','.join(DEFAULT_CURRENCIES)})"
    )
    
    parser.add_argument(
        "--skip-categorization",
        action="store_true",
        help="Skip AI categorization step (useful if API key is not available)"
    )
    
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging"
    )
    
    parser.add_argument(
        "--sheets-file-id",
        type=str,
        help="Google Sheets file ID for export"
    )
    
    parser.add_argument(
        "--sheets-name",
        type=str,
        help="Name of the worksheet/tab to create or update"
    )
    
    parser.add_argument(
        "--google-credentials",
        type=str,
        help="Path to Google service account credentials JSON file"
    )
    
    return parser.parse_args()


async def main():
    args = parse_arguments()
    
    if not args.skip_categorization and not args.api_key:
        logger.error("--api-key is required unless --skip-categorization is used")
        sys.exit(1)
    
    sheets_args = [args.sheets_file_id, args.sheets_name, args.google_credentials]
    if any(sheets_args) and not all(sheets_args):
        logger.error("All Google Sheets arguments (--sheets-file-id, --sheets-name, --google-credentials) are required when using Sheets export")
        sys.exit(1)
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    start_time = time.time()
    
    if args.output:
        output_path = args.output
    else:
        output_path = args.input.replace('.csv', DEFAULT_OUTPUT_SUFFIX)
    
    target_currencies = [currency.strip().upper() for currency in args.currencies.split(',')]
    
    openai_client = None
    if not args.skip_categorization:
        openai_client = AsyncOpenAI(api_key=args.api_key)
    
    logger.info("Transaction Processor")
    logger.info("=" * 50)
    logger.info(f"Input file: {args.input}")
    logger.info(f"Output file: {output_path}")
    logger.info(f"Target currencies: {', '.join(target_currencies)}")
    if args.skip_categorization:
        logger.info("AI categorization: DISABLED")
    else:
        logger.info(f"AI model: {args.model}")
    logger.info("=" * 50)
    
    logger.info("📖 Reading transactions from CSV...")
    transactions = read_transactions_from_csv(args.input)
    
    logger.info("🔍 Filtering external transactions...")
    external_transactions = filter_external_transactions(transactions)

    logger.info("📊 Grouping identical transactions...")
    grouped_transactions = group_transactions_by_description(external_transactions)

    logger.info("💱 Converting currencies...")
    grouped_transactions = await convert_currency_amounts(grouped_transactions, target_currencies)

    if not args.skip_categorization:
        grouped_transactions = await categorize_transactions(grouped_transactions, openai_client, args.model)
    else:
        logger.info("⏭️  Skipping AI categorization...")
    
    logger.info("=" * 50)
    logger.info("✨ Transaction processing complete!")
    logger.info(f"📊 Total unique transactions: {len(grouped_transactions)}")
    
    if not args.skip_categorization:
        category_counts = defaultdict(int)
        for transaction in grouped_transactions:
            category_counts[transaction.category] += 1
        
        logger.info("📁 Categories breakdown:")
        for category, count in sorted(category_counts.items()):
            logger.info(f"   • {category}: {count}")
    
    export_to_csv(grouped_transactions, output_path)
    
    if args.sheets_file_id and args.sheets_name and args.google_credentials:
        try:
            export_to_sheets(grouped_transactions, args.sheets_file_id, args.sheets_name, args.google_credentials)
        except Exception as e:
            logger.error(f"❌ Google Sheets export failed: {e}")
            logger.info("💡 CSV export was successful, continuing...")
    
    elapsed_time = time.time() - start_time
    logger.info(f"⏱️  Total processing time: {elapsed_time:.2f} seconds")
    logger.info("=" * 50)


if __name__ == "__main__":
    asyncio.run(main())
