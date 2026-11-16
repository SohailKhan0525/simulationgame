using System;

namespace Qofeno
{
    // Monetary values are integer pence. One reserved item belongs to exactly one shopper.
    public sealed class RetailShift
    {
        public const int OpeningMinute = 8 * 60;
        public const int ClosingMinute = 21 * 60;
        public static bool IsTradingAt(float minuteOfDay) =>
            minuteOfDay >= OpeningMinute && minuteOfDay < ClosingMinute;
        public const int SkuCount = 3;
        public const int ShelfCapacity = 6;
        public const int DeliveryCapacity = 96;
        static readonly string[] Names = { "Quayside Tea", "Night Ferry Cocoa", "Olive Grove Soap" };
        static readonly int[] Sizes = { 3, 3, 4 };
        static readonly int[] Costs = { 450, 600, 520 };
        static readonly int[] Prices = { 250, 325, 210 };

        [Serializable]
        public sealed class Snapshot
        {
            public int version = 1;
            public int cash = 4000;
            public int[] shelf = { 1, 1, 0 };
            public int[] delivered = { 3, 0, 0 };
            public int heldSku = -1;
            public int heldUnits;
            public int customerSku = -1;
            public bool scanned;
            public int receipts;
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
        static bool ValidSku(int sku) => sku >= 0 && sku < SkuCount;
        public static string NameOf(int sku) => ValidSku(sku) ? Names[sku] : "";
        public static int CaseSize(int sku) => ValidSku(sku) ? Sizes[sku] : 0;
        public static int CaseCost(int sku) => ValidSku(sku) ? Costs[sku] : 0;
        public static int UnitPrice(int sku) => ValidSku(sku) ? Prices[sku] : 0;
        public int GetShelf(int sku) => ValidSku(sku) ? data.shelf[sku] : 0;
        public int GetDelivered(int sku) => ValidSku(sku) ? data.delivered[sku] : 0;

        public bool Order(int[] cases)
        {
            if (cases == null || cases.Length != SkuCount) return false;
            int bill = 0;
            for (int i = 0; i < SkuCount; i++)
            {
                int count = cases[i];
                if (count < 0 || count > DeliveryCapacity / Sizes[i]) return false;
                int units = count * Sizes[i];
                int carried = data.heldSku == i ? data.heldUnits : 0;
                if (data.delivered[i] + carried + units > DeliveryCapacity) return false;
                bill += count * Costs[i];
            }
            if (bill == 0 || bill > data.cash) return false;
            for (int i = 0; i < SkuCount; i++) data.delivered[i] += cases[i] * Sizes[i];
            data.cash -= bill;
            return true;
        }

        public bool Take(int sku)
        {
            if (!ValidSku(sku) || data.heldUnits > 0 || data.delivered[sku] == 0) return false;
            data.heldSku = sku;
            data.heldUnits = Math.Min(data.delivered[sku], Sizes[sku]);
            data.delivered[sku] -= data.heldUnits;
            return true;
        }

        public bool Stock()
        {
            if (!ValidSku(data.heldSku)) return false;
            int placed = Math.Min(data.heldUnits, ShelfCapacity - data.shelf[data.heldSku]);
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

        public bool BeginSale(int sku)
        {
            if (!ValidSku(sku) || data.customerSku != -1 || data.shelf[sku] == 0) return false;
            data.shelf[sku]--;
            data.customerSku = sku;
            return true;
        }

        public bool Scan()
        {
            if (!ValidSku(data.customerSku) || data.scanned) return false;
            data.scanned = true;
            return true;
        }

        public bool Pay()
        {
            if (!data.scanned || !ValidSku(data.customerSku)) return false;
            int price = Prices[data.customerSku];
            if (data.cash > int.MaxValue - price || data.receipts == int.MaxValue) return false;
            data.cash += price;
            data.customerSku = -1;
            data.scanned = false;
            data.receipts++;
            return true;
        }

        static Snapshot Copy(Snapshot value)
        {
            return new Snapshot {
                version = value.version, cash = value.cash, shelf = (int[])value.shelf.Clone(),
                delivered = (int[])value.delivered.Clone(), heldSku = value.heldSku, heldUnits = value.heldUnits,
                customerSku = value.customerSku, scanned = value.scanned, receipts = value.receipts
            };
        }

        public Snapshot Capture() => Copy(data);

        public static bool TryRestore(Snapshot value, out RetailShift restored)
        {
            restored = null;
            if (value == null || value.version != 1 || value.cash < 0 || value.receipts < 0 ||
                value.shelf == null || value.shelf.Length != SkuCount ||
                value.delivered == null || value.delivered.Length != SkuCount) return false;
            if (value.heldSku != -1 && !ValidSku(value.heldSku)) return false;
            if (value.heldSku == -1 ? value.heldUnits != 0 : value.heldUnits < 1 || value.heldUnits > Sizes[value.heldSku]) return false;
            if (value.customerSku != -1 && !ValidSku(value.customerSku)) return false;
            if (value.scanned && value.customerSku == -1) return false;
            for (int i = 0; i < SkuCount; i++)
            {
                int carried = i == value.heldSku ? value.heldUnits : 0;
                if (value.shelf[i] < 0 || value.shelf[i] > ShelfCapacity ||
                    value.delivered[i] < 0 || value.delivered[i] > DeliveryCapacity - carried) return false;
            }
            restored = new RetailShift(Copy(value));
            return true;
        }
    }
}
