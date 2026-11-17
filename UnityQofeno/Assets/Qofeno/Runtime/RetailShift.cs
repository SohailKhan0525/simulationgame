using System;

namespace Qofeno
{
    // Money is stored in integer pence. A shopper owns the goods and the agreed prices from reservation to payment.
    public sealed class RetailShift
    {
        public const int OpeningMinute = 8 * 60;
        public const int ClosingMinute = 21 * 60;
        public const int BaseSkuCount = 3;
        public const int SkuCount = 6;
        public const int ShelfCapacity = 6;
        public const int DeliveryCapacity = 96;
        public const int PriceStep = 25;
        public const int MaxBasket = 3;
        public const int ExpansionCost = 3000;
        public const int StockerCost = 4500;
        public const int ContractReceipts = 15;
        public const int ContractBonus = 2500;
        static readonly string[] Names = { "Quayside Tea", "Night Ferry Cocoa", "Olive Grove Soap",
            "Coast Oats", "Jetty Coffee", "Pier Tomatoes" };
        static readonly int[] Sizes = { 3, 3, 4, 6, 4, 5 };
        static readonly int[] Costs = { 450, 600, 520, 550, 900, 500 };
        static readonly int[] MarketPrices = { 250, 325, 210, 165, 350, 185 };

        public static bool IsTradingAt(float minuteOfDay) =>
            minuteOfDay >= OpeningMinute && minuteOfDay < ClosingMinute;

        [Serializable]
        public sealed class Snapshot
        {
            public int version = 2;
            public int cash = 4000;
            public int[] shelf = { 5, 4, 2, 0, 0, 0 };
            public int[] delivered = { 3, 0, 0, 0, 0, 0 };
            public int heldSku = -1;
            public int heldUnits;
            // The v1 format stored its entire checkout in these two fields.
            public int customerSku = -1;
            public bool scanned;
            public int receipts;

            public int[] prices = (int[])MarketPrices.Clone();
            public int[] basket = Array.Empty<int>();
            public int[] agreedPrices = Array.Empty<int>();
            public int scannedCount;
            public bool expanded, hasStocker, contractSigned;
            public int todaySales, todayWholesale, todayReceipts, todayInvestment, todayOtherIncome;
            public int lastSales, lastWholesale, lastReceipts, lastInvestment, lastOtherIncome;

            internal Snapshot Copy()
            {
                var result = (Snapshot)MemberwiseClone();
                result.shelf = (int[])shelf.Clone();
                result.delivered = (int[])delivered.Clone();
                result.prices = (int[])prices?.Clone();
                result.basket = (int[])basket?.Clone();
                result.agreedPrices = (int[])agreedPrices?.Clone();
                return result;
            }
        }

        readonly Snapshot data;
        public RetailShift() : this(new Snapshot()) { }
        RetailShift(Snapshot source) { data = source; }

        public int Cash => data.cash;
        public int HeldSku => data.heldSku;
        public int HeldUnits => data.heldUnits;
        public int CustomerSku => data.customerSku;
        public bool Scanned => data.scanned;
        public int ReceiptCount => data.receipts;
        public int BasketCount => data.basket.Length;
        public int ScannedCount => data.scannedCount;
        public int BasketTotal => SumPrices(BasketCount);
        public int ScannedTotal => SumPrices(ScannedCount);
        public int CurrentItemPrice => BasketPriceAt(Math.Min(ScannedCount, BasketCount - 1));
        public int BasketSkuAt(int index) => index >= 0 && index < BasketCount ? data.basket[index] : -1;
        public int BasketPriceAt(int index) => index >= 0 && index < BasketCount ? data.agreedPrices[index] : 0;

        public bool IsExpanded => data.expanded;
        public bool HasStocker => data.hasStocker;
        public int Capacity => data.expanded ? ShelfCapacity * 2 : ShelfCapacity;
        public bool IsUnlocked(int sku) => ValidSku(sku) && (sku < BaseSkuCount || IsExpanded);
        public int CapacityFor(int sku) => ShelfSpace(sku, IsExpanded);

        static int ShelfSpace(int sku, bool expanded)
        {
            if (!ValidSku(sku)) return 0;
            if (sku < BaseSkuCount) return expanded ? ShelfCapacity * 2 : ShelfCapacity;
            return expanded ? ShelfCapacity : 0;
        }

        public bool CanExpand => !IsExpanded && CanInvest(ExpansionCost);
        public bool CanHireStocker => !HasStocker && CanInvest(StockerCost);
        public bool ContractSigned => data.contractSigned;
        public bool CanSignContract => !ContractSigned && IsExpanded && HasStocker &&
            ReceiptCount >= ContractReceipts && Cash <= int.MaxValue - ContractBonus;

        public int TodaySales => data.todaySales;
        public int TodayWholesale => data.todayWholesale;
        public int TodayInvestment => data.todayInvestment;
        public int TodayReceipts => data.todayReceipts;
        public int TodayOtherIncome => data.todayOtherIncome;
        public int LastSales => data.lastSales;
        public int LastWholesale => data.lastWholesale;
        public int LastInvestment => data.lastInvestment;
        public int LastReceipts => data.lastReceipts;
        public int LastOtherIncome => data.lastOtherIncome;

        static bool ValidSku(int sku) => sku >= 0 && sku < SkuCount;
        public static string NameOf(int sku) => ValidSku(sku) ? Names[sku] : "";
        public static int CaseSize(int sku) => ValidSku(sku) ? Sizes[sku] : 0;
        public static int CaseCost(int sku) => ValidSku(sku) ? Costs[sku] : 0;
        public static int UnitPrice(int sku) => ValidSku(sku) ? MarketPrices[sku] : 0;
        public int Price(int sku) => ValidSku(sku) ? data.prices[sku] : 0;
        public int GetShelf(int sku) => ValidSku(sku) ? data.shelf[sku] : 0;
        public int GetDelivered(int sku) => ValidSku(sku) ? data.delivered[sku] : 0;

        int SumPrices(int count)
        {
            int total = 0;
            for (int i = 0; i < count; i++) total += data.agreedPrices[i];
            return total;
        }

        static bool ValidPrice(int sku, int price)
        {
            // Keep even the lowest allowed price above the per-unit wholesale cost.
            return ValidSku(sku) && price > Costs[sku] / Sizes[sku] &&
                price <= MarketPrices[sku] + 6 * PriceStep && (price - MarketPrices[sku]) % PriceStep == 0;
        }

        public bool CanChangePrice(int sku, int steps) =>
            IsUnlocked(sku) && (steps == -1 || steps == 1) && ValidPrice(sku, Price(sku) + steps * PriceStep);

        public bool ChangePrice(int sku, int steps)
        {
            if (!CanChangePrice(sku, steps)) return false;
            data.prices[sku] += steps * PriceStep;
            return true;
        }

        public bool WillBuy(int sku, int customerSeed)
        {
            if (!IsUnlocked(sku)) return false;
            int extraSteps = (Price(sku) - MarketPrices[sku]) / PriceStep;
            if (extraSteps <= 0) return true;
            // Each visitor has a stable spending preference for each SKU. The most expensive price still has buyers.
            uint preference = unchecked((uint)customerSeed * 2654435761u + (uint)(sku + 1) * 2246822519u);
            preference ^= preference >> 16;
            return preference % 100 < 100 - extraSteps * 12;
        }

        public bool Order(int[] cases)
        {
            if (cases == null || (cases.Length != BaseSkuCount && cases.Length != SkuCount)) return false;
            int bill = 0;
            for (int i = 0; i < cases.Length; i++)
            {
                int count = cases[i];
                if (count < 0 || count > DeliveryCapacity / Sizes[i] || (count > 0 && !IsUnlocked(i))) return false;
                int units = count * Sizes[i];
                int carried = data.heldSku == i ? data.heldUnits : 0;
                if (data.delivered[i] + carried + units > DeliveryCapacity) return false;
                bill += count * Costs[i];
            }
            if (bill == 0 || bill > Cash || data.todayWholesale > int.MaxValue - bill) return false;
            for (int i = 0; i < cases.Length; i++) data.delivered[i] += cases[i] * Sizes[i];
            data.cash -= bill;
            data.todayWholesale += bill;
            return true;
        }

        public bool Take(int sku)
        {
            if (!IsUnlocked(sku) || data.heldUnits > 0 || data.delivered[sku] == 0) return false;
            data.heldSku = sku;
            data.heldUnits = Math.Min(data.delivered[sku], Sizes[sku]);
            data.delivered[sku] -= data.heldUnits;
            return true;
        }

        public bool Stock()
        {
            if (!ValidSku(data.heldSku)) return false;
            int placed = Math.Min(data.heldUnits, CapacityFor(data.heldSku) - data.shelf[data.heldSku]);
            if (placed <= 0) return false;
            data.shelf[data.heldSku] += placed;
            data.heldUnits -= placed;
            if (data.heldUnits == 0) data.heldSku = -1;
            return true;
        }

        public bool ReturnCarton()
        {
            if (!ValidSku(data.heldSku)) return false;
            data.delivered[data.heldSku] += data.heldUnits;
            data.heldSku = -1;
            data.heldUnits = 0;
            return true;
        }

        bool CanInvest(int cost)
        {
            if (Cash < cost || TodayInvestment > int.MaxValue - cost) return false;
            // Leave enough cash or goods to buy the cheapest case after this purchase.
            long workingCapital = (long)Cash - cost + BasketTotal;
            for (int sku = 0; sku < SkuCount; sku++)
            {
                int goods = GetShelf(sku) + GetDelivered(sku) + (HeldSku == sku ? HeldUnits : 0);
                workingCapital += (long)goods * Price(sku);
            }
            return workingCapital >= Costs[0];
        }

        public bool TryExpand()
        {
            if (!CanExpand) return false;
            data.cash -= ExpansionCost;
            data.todayInvestment += ExpansionCost;
            data.expanded = true;
            return true;
        }

        public bool TryHireStocker()
        {
            if (!CanHireStocker) return false;
            data.cash -= StockerCost;
            data.todayInvestment += StockerCost;
            data.hasStocker = true;
            return true;
        }

        public bool SignContract()
        {
            if (!CanSignContract) return false;
            data.contractSigned = true;
            data.cash += ContractBonus;
            data.todayOtherIncome = ContractBonus;
            return true;
        }

        public int RestockOne()
        {
            if (!HasStocker) return -1;
            int target = -1;
            for (int sku = 0; sku < SkuCount; sku++)
                if (GetDelivered(sku) > 0 && GetShelf(sku) < CapacityFor(sku) &&
                    (target < 0 || GetShelf(sku) < GetShelf(target))) target = sku;
            if (target >= 0)
            {
                data.delivered[target]--;
                data.shelf[target]++;
            }
            return target;
        }

        public bool BeginSale(int sku)
        {
            if (!IsUnlocked(sku) || BasketCount != 0 || GetShelf(sku) == 0) return false;
            Reserve(new[] { sku });
            return true;
        }

        public bool BeginBasket(int preferredSku, int customerSeed, int maxItems = MaxBasket)
        {
            if (!IsUnlocked(preferredSku) || BasketCount != 0 || maxItems < 1 || maxItems > MaxBasket) return false;
            int wanted = 1 + (int)(unchecked((uint)customerSeed + 1u) % (uint)maxItems);
            var items = new int[wanted];
            var selected = new int[SkuCount];
            int count = 0;
            for (int pass = 0; pass < wanted && count < wanted; pass++)
            {
                int previousCount = count;
                for (int offset = 0; offset < SkuCount && count < wanted; offset++)
                {
                    int sku = (preferredSku + offset) % SkuCount;
                    if (selected[sku] >= GetShelf(sku) || !WillBuy(sku, customerSeed)) continue;
                    items[count++] = sku;
                    selected[sku]++;
                }
                if (count == previousCount) break;
            }
            if (count == 0) return false;
            Array.Resize(ref items, count);
            Reserve(items);
            return true;
        }

        void Reserve(int[] items)
        {
            data.basket = items;
            data.agreedPrices = new int[items.Length];
            for (int i = 0; i < items.Length; i++)
            {
                int sku = items[i];
                data.shelf[sku]--;
                data.agreedPrices[i] = Price(sku);
            }
            SyncCheckout();
        }

        void SyncCheckout()
        {
            data.customerSku = BasketSkuAt(Math.Min(ScannedCount, BasketCount - 1));
            data.scanned = BasketCount > 0 && ScannedCount == BasketCount;
        }

        public bool Scan() => ScanAt(ScannedCount);

        public bool ScanAt(int index)
        {
            if (index < ScannedCount || index >= BasketCount) return false;
            // The paid part of the ticket is a prefix. Move the selected line and its shelf quote together.
            int next = ScannedCount;
            int sku = data.basket[next];
            int price = data.agreedPrices[next];
            data.basket[next] = data.basket[index];
            data.agreedPrices[next] = data.agreedPrices[index];
            data.basket[index] = sku;
            data.agreedPrices[index] = price;
            data.scannedCount++;
            SyncCheckout();
            return true;
        }

        public bool Pay()
        {
            if (!Scanned) return false;
            int total = BasketTotal;
            if (Cash > int.MaxValue - total || TodaySales > int.MaxValue - total || ReceiptCount == int.MaxValue)
                return false;
            data.cash += total;
            data.todaySales += total;
            data.receipts++;
            data.todayReceipts++;
            data.basket = Array.Empty<int>();
            data.agreedPrices = Array.Empty<int>();
            data.scannedCount = 0;
            SyncCheckout();
            return true;
        }

        public void CloseDay()
        {
            data.lastSales = TodaySales;
            data.lastWholesale = TodayWholesale;
            data.lastReceipts = TodayReceipts;
            data.lastInvestment = TodayInvestment;
            data.lastOtherIncome = TodayOtherIncome;
            data.todaySales = data.todayWholesale = data.todayReceipts = data.todayInvestment = 0;
            data.todayOtherIncome = 0;
        }

        public Snapshot Capture() => data.Copy();

        public static bool TryRestore(Snapshot value, out RetailShift restored)
        {
            restored = null;
            if (value == null || (value.version != 1 && value.version != 2) || value.cash < 0 || value.receipts < 0)
                return false;
            int savedSkuCount = value.version == 1 ? BaseSkuCount : SkuCount;
            bool expanded = value.version == 2 && value.expanded;
            int unlockedCount = expanded ? SkuCount : BaseSkuCount;
            if (value.shelf == null || value.shelf.Length != savedSkuCount ||
                value.delivered == null || value.delivered.Length != savedSkuCount) return false;
            if (value.heldSku < -1 || value.heldSku >= unlockedCount) return false;
            if (value.heldSku == -1 ? value.heldUnits != 0 : value.heldUnits < 1 || value.heldUnits > Sizes[value.heldSku]) return false;
            if (value.customerSku < -1 || value.customerSku >= unlockedCount) return false;
            if (value.scanned && value.customerSku == -1) return false;
            for (int i = 0; i < savedSkuCount; i++)
            {
                int carried = i == value.heldSku ? value.heldUnits : 0;
                if (value.shelf[i] < 0 || value.shelf[i] > ShelfSpace(i, expanded) ||
                    value.delivered[i] < 0 || value.delivered[i] > DeliveryCapacity - carried ||
                    (i >= unlockedCount && value.delivered[i] > 0)) return false;
            }

            if (value.version == 1)
            {
                var upgraded = new Snapshot {
                    cash = value.cash, heldSku = value.heldSku, heldUnits = value.heldUnits, customerSku = value.customerSku,
                    scanned = value.scanned, receipts = value.receipts
                };
                Array.Copy(value.shelf, upgraded.shelf, BaseSkuCount);
                Array.Copy(value.delivered, upgraded.delivered, BaseSkuCount);
                if (value.customerSku >= 0)
                {
                    upgraded.basket = new[] { value.customerSku };
                    upgraded.agreedPrices = new[] { UnitPrice(value.customerSku) };
                    upgraded.scannedCount = value.scanned ? 1 : 0;
                }
                restored = new RetailShift(upgraded);
                return true;
            }

            if (value.prices == null || value.prices.Length != SkuCount ||
                value.basket == null || value.basket.Length > MaxBasket || value.agreedPrices == null ||
                value.basket.Length != value.agreedPrices.Length || value.scannedCount < 0 ||
                value.scannedCount > value.basket.Length) return false;
            for (int i = 0; i < SkuCount; i++)
                if (!ValidPrice(i, value.prices[i]) || (i >= unlockedCount && value.prices[i] != MarketPrices[i]))
                    return false;
            for (int i = 0; i < value.basket.Length; i++)
                if (value.basket[i] >= unlockedCount || !ValidPrice(value.basket[i], value.agreedPrices[i])) return false;
            int current = value.basket.Length == 0 ? -1 : value.basket[Math.Min(value.scannedCount, value.basket.Length - 1)];
            if (value.customerSku != current || value.scanned != (current >= 0 && value.scannedCount == value.basket.Length))
                return false;
            if (value.todaySales < 0 || value.todayWholesale < 0 || value.todayInvestment < 0 || value.todayReceipts < 0 ||
                value.lastSales < 0 || value.lastWholesale < 0 || value.lastInvestment < 0 || value.lastReceipts < 0 ||
                (long)value.todayReceipts + value.lastReceipts > value.receipts) return false;
            if (value.contractSigned && (!value.expanded || !value.hasStocker || value.receipts < ContractReceipts))
                return false;
            if ((value.todayOtherIncome != 0 && value.todayOtherIncome != ContractBonus) ||
                (value.lastOtherIncome != 0 && value.lastOtherIncome != ContractBonus) ||
                value.todayOtherIncome + value.lastOtherIncome > (value.contractSigned ? ContractBonus : 0))
                return false;

            restored = new RetailShift(value.Copy());
            return true;
        }
    }
}
