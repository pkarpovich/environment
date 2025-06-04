import json
from collections import defaultdict
from csv import DictReader
from enum import Enum
from typing import Annotated
import httpx

from openai import OpenAI
from pydantic import BaseModel, Field, field_validator

OPENAI_API_KEY = ""
OPENAI_MODEL = "gpt-4.1"
TRANSACTIONS_PATH = "./transactions.csv"

client = OpenAI(api_key=OPENAI_API_KEY)

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

{transactions}

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

For each transaction, add a "category" field with the most appropriate category.
Return a JSON array with all original fields plus the new category field.
"""

PROMPT_4_GROUP_AND_COUNT = """
Group and aggregate these categorized transactions:

{transactions}

Tasks:
1. Identify transactions with identical descriptions
2. Group them together:
   - Sum the amounts
   - Keep the earliest date from the group
   - Set "occurrences" field to the count of grouped transactions
3. For transactions that appear only once, set "occurrences" to 1

Return a JSON array with the grouped transactions.
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

    return result


def get_exchange_rates(base_currency: str = "USD") -> dict[str, float]:
    """Fetch current exchange rates from ExchangeRate-API."""
    try:
        with httpx.Client() as client:
            response = client.get(f"https://api.exchangerate-api.com/v4/latest/{base_currency}")
            response.raise_for_status()
            data = response.json()
            return {currency: float(rate) for currency, rate in data["rates"].items()}
    except Exception as e:
        print(f"Error fetching exchange rates: {e}")
        return {}


def convert_currency_amounts(grouped_transactions: list[GroupedTransaction], target_currencies: list[str]) -> list[GroupedTransaction]:
    """Convert all transaction amounts to target currencies."""
    # Get USD exchange rates once
    usd_rates = get_exchange_rates("USD")
    
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


def main():
    print("\n📖 Step 1: Reading transactions from CSV...")
    transactions = read_transactions_from_csv(TRANSACTIONS_PATH)

    print("\n📊 Step 2: Grouping identical transactions...")
    grouped_transactions = group_transactions_by_description(transactions)

    print("\n💱 Step 3: Converting currencies...")
    target_currencies = ["USD", "EUR", "PLN", "BYN"]
    grouped_transactions = convert_currency_amounts(grouped_transactions, target_currencies)

    print("\n🏷️ Step 4: Categorizing transactions...")

    transactions_json = json.dumps([t.model_dump() for t in grouped_transactions], ensure_ascii=False)

    response = client.responses.parse(
        model=OPENAI_MODEL,
        input=PROMPT_3_CATEGORIZE.format(transactions=transactions_json),
        temperature=0.0,
        text_format=Transactions,
    )
    
    categorized_transactions = response.parsed.transactions if response.parsed else []
    print(f"✅ Categorized {len(categorized_transactions)} transactions")



if __name__ == "__main__":
    main()
