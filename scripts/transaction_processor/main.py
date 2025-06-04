import asyncio
import json
import logging
import sys
import time
from collections import defaultdict
from csv import DictReader, DictWriter
from enum import Enum
from typing import Annotated
import httpx

from openai import AsyncOpenAI
from pydantic import BaseModel, Field, field_validator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)-8s | %(message)s',
    datefmt='%H:%M:%S',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

OPENAI_API_KEY = ""
OPENAI_MODEL = "gpt-4.1"
TRANSACTIONS_PATH = "./transactions.csv"

client = AsyncOpenAI(api_key=OPENAI_API_KEY)

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

PROMPT_1_FILTER = """
You are processing bank transactions. Remove internal transfers from this data:

{transactions}

Remove any transaction where the description contains 'savings' or 'pockets' (these are internal transfers between accounts).

Return a JSON array with only the valid external transactions, keeping all original fields.
"""

PROMPT_3_CATEGORIZE = """
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


async def categorize_transactions(grouped_transactions: list[GroupedTransaction]) -> list[GroupedTransaction]:
    """Categorize transactions using AI based on their descriptions."""
    logger.info("🏷️ Categorizing transactions...")
    initial_count = len(grouped_transactions)

    # Simplify transactions for AI - only send description and category
    simplified_transactions = [
        {"description": t.description, "category": ""} 
        for t in grouped_transactions
    ]
    transactions_json = json.dumps(simplified_transactions, ensure_ascii=False)

    response = await client.responses.parse(
        model=OPENAI_MODEL,
        instructions=PROMPT_3_CATEGORIZE,
        input=transactions_json,
        temperature=0.0,
        text_format=CategorizedTransactions,
    )

    categorized_results = response.output_parsed or []
    
    # Validate response count
    if len(categorized_results.transactions) != initial_count:
        logger.warning(f"⚠️  Count mismatch: sent {initial_count} transactions, received {len(categorized_results.transactions)} categorized")
    
    # Map categories back to original transactions
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
    
    # Final validation
    final_count = len(grouped_transactions)
    if final_count != initial_count:
        logger.error(f"❌ Transaction count changed during categorization: {initial_count} → {final_count}")
    else:
        logger.info(f"✅ Successfully categorized {len(grouped_transactions)} transactions")
    
    return grouped_transactions


async def convert_currency_amounts(grouped_transactions: list[GroupedTransaction], target_currencies: list[str]) -> list[GroupedTransaction]:
    """Convert all transaction amounts to target currencies."""
    # Get USD exchange rates once
    usd_rates = await get_exchange_rates("USD")
    
    for transaction in grouped_transactions:
        # First convert everything to USD
        total_usd = 0.0
        for currency, amount in transaction.amounts.items():
            if currency == "USD":
                total_usd += amount
            else:
                # Convert to USD (1 / rate because we need USD per foreign currency)
                rate_to_usd = 1.0 / usd_rates.get(currency, 1.0)
                total_usd += amount * rate_to_usd
        
        # Then convert USD total to all target currencies
        converted_amounts = {}
        for target_currency in target_currencies:
            if target_currency == "USD":
                converted_amounts[target_currency] = round(total_usd, 2)
            else:
                rate = usd_rates.get(target_currency, 1.0)
                converted_amounts[target_currency] = round(total_usd * rate, 2)
        
        transaction.converted_amounts = converted_amounts
    
    return grouped_transactions


def export_to_csv(grouped_transactions: list[GroupedTransaction], output_path: str):
    """Export grouped transactions to CSV with flattened structure."""
    logger.info(f"💾 Exporting results to {output_path}...")
    
    # Prepare rows with flattened structure
    rows = []
    for transaction in grouped_transactions:
        row = {
            'description': transaction.description,
            'category': transaction.category,
            'occurrences': transaction.occurrences,
            'comment': transaction.comment,
        }
        
        # Add original amounts with currency suffix
        for currency, amount in transaction.amounts.items():
            row[f'amount_{currency}'] = round(amount, 2)
        
        # Add converted amounts with currency suffix
        for currency, amount in transaction.converted_amounts.items():
            row[f'converted_{currency}'] = round(amount, 2)
        
        rows.append(row)
    
    # Get all unique field names with specific ordering
    if rows:
        # Define the order of fields
        base_fields = ['description', 'category', 'occurrences', 'comment']
        
        # Collect all unique amount and converted fields from ALL rows
        all_amount_fields = set()
        all_converted_fields = set()
        
        for row in rows:
            all_amount_fields.update([k for k in row.keys() if k.startswith('amount_')])
            all_converted_fields.update([k for k in row.keys() if k.startswith('converted_')])
        
        # Sort the fields
        amount_fields = sorted(list(all_amount_fields))
        converted_fields = sorted(list(all_converted_fields))
        
        # Combine in logical order
        fieldnames = base_fields + amount_fields + converted_fields
        
        # Ensure all rows have all fields (fill missing with empty string)
        for row in rows:
            for field in fieldnames:
                if field not in row:
                    row[field] = ''
        
        # Write CSV
        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        
        logger.info(f"✅ Successfully exported {len(rows)} transactions to {output_path}")
    else:
        logger.warning("⚠️  No transactions to export")


async def main():
    start_time = time.time()
    
    logger.info("📖 Reading transactions from CSV...")
    transactions = read_transactions_from_csv(TRANSACTIONS_PATH)

    logger.info("📊 Grouping identical transactions...")
    grouped_transactions = group_transactions_by_description(transactions)

    logger.info("💱 Converting currencies...")
    target_currencies = ["USD", "EUR", "PLN", "BYN"]
    grouped_transactions = await convert_currency_amounts(grouped_transactions, target_currencies)

    # Step 4: Categorize transactions
    grouped_transactions = await categorize_transactions(grouped_transactions)
    
    # Log final summary
    logger.info("=" * 50)
    logger.info("✨ Transaction processing complete!")
    logger.info(f"📊 Total unique transactions: {len(grouped_transactions)}")
    
    # Count by category
    category_counts = defaultdict(int)
    for transaction in grouped_transactions:
        category_counts[transaction.category] += 1
    
    logger.info("📁 Categories breakdown:")
    for category, count in sorted(category_counts.items()):
        logger.info(f"   • {category}: {count}")
    
    # Export results to CSV
    output_path = TRANSACTIONS_PATH.replace('.csv', '_processed.csv')
    export_to_csv(grouped_transactions, output_path)
    
    elapsed_time = time.time() - start_time
    logger.info(f"⏱️  Total processing time: {elapsed_time:.2f} seconds")
    logger.info("=" * 50)



if __name__ == "__main__":
    asyncio.run(main())
