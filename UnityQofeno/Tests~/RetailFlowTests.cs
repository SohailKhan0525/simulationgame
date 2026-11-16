using System;
using System.Text.Json;
using Qofeno;

internal static class RetailFlowTests
{
    private static int assertions;

    private static void Check(bool condition, string message)
    {
        assertions++;
        if (!condition) throw new InvalidOperationException(message);
    }

    private static int Units(RetailShift shift, int sku)
    {
        return shift.GetShelf(sku) + shift.GetDelivered(sku)
            + (shift.HeldSku == sku ? shift.HeldUnits : 0)
            + (shift.CustomerSku == sku ? 1 : 0);
    }

    private static void CheckTradingHours()
    {
        Check(!RetailShift.IsTradingAt(0f), "Midnight is outside trading hours.");
        Check(!RetailShift.IsTradingAt(479.99f), "The minute before eight is closed.");
        Check(RetailShift.IsTradingAt(480f), "Opening at 08:00 is inclusive.");
        Check(RetailShift.IsTradingAt(720f), "Noon is inside trading hours.");
        Check(RetailShift.IsTradingAt(1259.99f), "The final fraction before 21:00 is open.");
        Check(!RetailShift.IsTradingAt(1260f), "Closing at 21:00 is exclusive.");
        Check(!RetailShift.IsTradingAt(1439.99f), "The final fraction before midnight is closed.");
    }

    private static void CheckShelfAndTill()
    {
        var shift = new RetailShift();
        Check(shift.Cash == 4000, "Opening float must be £40.");
        Check(shift.GetShelf(0) == 1 && shift.GetShelf(1) == 1 && shift.GetShelf(2) == 0,
            "Opening shelves should have one tea and one cocoa.");
        Check(shift.GetDelivered(0) == 3, "A tea case should be ready to collect.");
        Check(!shift.BeginSale(2), "An empty soap shelf must not fulfil a sale.");
        Check(!shift.Pay() && !shift.Scan(), "An idle till cannot charge or scan.");

        Check(shift.BeginSale(0), "Reserve a tea.");
        Check(shift.CustomerSku == 0 && shift.GetShelf(0) == 0, "A reserved tea leaves the shelf.");
        Check(!shift.BeginSale(1) && !shift.Pay(), "An active unscanned purchase blocks a second basket and payment.");
        Check(shift.Scan() && shift.Scanned, "The register records the scan.");
        Check(!shift.Scan(), "A second scan should not duplicate the item.");
        Check(shift.Pay(), "Complete contactless payment.");
        Check(shift.Cash == 4250 && shift.ReceiptCount == 1, "The receipt adds exactly £2.50.");
        Check(shift.CustomerSku == -1 && !shift.Scanned && !shift.Pay(),
            "Payment clears the basket and cannot be posted twice.");
    }

    private static void CheckCartons()
    {
        var shift = new RetailShift();
        Check(!shift.Take(2) && !shift.Stock() && !shift.ReturnCarton(), "Empty deliveries and hands cannot produce stock.");
        Check(shift.Take(0) && shift.HeldUnits == 3, "Picking up the opening carton must move three teas.");
        Check(!shift.Take(0) && shift.ReturnCarton(), "Return a held carton without duplicating it.");
        Check(shift.HeldSku == -1 && shift.GetDelivered(0) == 3, "Returned stock is available again.");
        Check(shift.Order(new[] { 2, 0, 0 }), "Buy two cases of tea.");
        Check(shift.GetDelivered(0) == 9 && shift.Cash == 3100, "Each case adds three teas and costs £4.50.");
        Check(shift.Take(0) && shift.Stock() && shift.GetShelf(0) == 4, "Stock one complete case.");
        Check(shift.Take(0) && shift.Stock(), "Stock the two remaining shelf slots.");
        Check(shift.GetShelf(0) == 6 && shift.HeldUnits == 1, "A partially filled carton retains the overflow unit.");
        Check(!shift.Stock() && shift.ReturnCarton(), "A packed shelf does not consume further units.");
        Check(shift.GetDelivered(0) == 4 && Units(shift, 0) == 10, "Unplaced stock remains retrievable.");
    }

    private static void CheckOrderValidation()
    {
        var shift = new RetailShift();
        foreach (var invalid in new[] {
            null, new[] { 1 }, new[] { 0, 0, 0 }, new[] { 1, -1, 0 },
            new[] { 9, 0, 0 }, new[] { int.MaxValue, 0, 0 }
        })
        {
            Check(!shift.Order(invalid), "Reject an invalid or unaffordable order.");
            Check(shift.Cash == 4000 && shift.GetDelivered(0) == 3 && shift.GetDelivered(1) == 0
                && shift.GetDelivered(2) == 0, "A rejected order must leave funds and inventory intact.");
        }
    }

    private static readonly JsonSerializerOptions SaveOptions = new JsonSerializerOptions { IncludeFields = true };

    private static RetailShift Reload(RetailShift shift)
    {
        string json = JsonSerializer.Serialize(shift.Capture(), SaveOptions);
        var snapshot = JsonSerializer.Deserialize<RetailShift.Snapshot>(json, SaveOptions);
        Check(RetailShift.TryRestore(snapshot, out var restored), "A valid saved shift should reload.");
        Check(restored != shift && JsonSerializer.Serialize(restored.Capture(), SaveOptions) == json,
            "A restored shift must retain every public save field.");
        return restored;
    }

    private static void CheckSaves()
    {
        var shift = new RetailShift();
        Check(shift.Take(0) && shift.BeginSale(1) && shift.Scan(), "Prepare a carried carton and scanned item.");
        var restored = Reload(shift);
        Check(restored.HeldSku == 0 && restored.HeldUnits == 3, "The carried carton survives suspension.");
        Check(restored.CustomerSku == 1 && restored.Scanned && restored.Pay() && !restored.Pay(),
            "A saved scan can settle exactly once.");
        Check(restored.Cash == 4325 && shift.Cash == 4000, "Restored shifts must own their state.");

        var detached = restored.Capture();
        detached.shelf[0] = 6;
        Check(restored.GetShelf(0) == 1, "Snapshots returned to a caller cannot mutate live inventory.");
        Check(RetailShift.TryRestore(detached, out var isolated), "The detached snapshot should be valid.");
        detached.shelf[0] = 0;
        Check(isolated.GetShelf(0) == 6, "External mutation cannot alter an already-restored shift.");

        Action<RetailShift.Snapshot>[] corruptions = {
            value => value.version = 44,
            value => value.cash = -1,
            value => value.shelf = null,
            value => value.delivered = new int[2],
            value => value.shelf[0] = 7,
            value => value.delivered[0] = int.MaxValue,
            value => value.heldSku = 3,
            value => value.heldUnits = 1,
            value => value.customerSku = 3,
            value => value.scanned = true
        };
        foreach (var corrupt in corruptions)
        {
            var bad = new RetailShift().Capture();
            corrupt(bad);
            Check(!RetailShift.TryRestore(bad, out var invalid) && invalid == null,
                "Malformed saves must not become playable.");
        }

        var overflow = new RetailShift().Capture();
        overflow.cash = int.MaxValue - 2;
        Check(RetailShift.TryRestore(overflow, out var rich) && rich.BeginSale(0) && rich.Scan(),
            "A valid near-limit balance should load.");
        Check(!rich.Pay() && rich.Scanned && rich.CustomerSku == 0 && rich.Cash == overflow.cash,
            "An unrepresentable payment must preserve the entire pending sale.");
    }

    private static void CheckMixedShift()
    {
        var shift = new RetailShift();
        var random = new Random(1703);
        int[] goods = { 4, 1, 0 };
        int till = 4000, receipts = 0;
        for (int step = 0; step < 8000; step++)
        {
            int sku = random.Next(3);
            switch (random.Next(7))
            {
                case 0:
                    int[] cases = { random.Next(3), random.Next(3), random.Next(3) };
                    if (shift.Order(cases))
                    {
                        for (int i = 0; i < cases.Length; i++)
                        {
                            goods[i] += cases[i] * RetailShift.CaseSize(i);
                            till -= cases[i] * RetailShift.CaseCost(i);
                        }
                    }
                    break;
                case 1: shift.Take(sku); break;
                case 2: shift.Stock(); break;
                case 3: shift.ReturnCarton(); break;
                case 4: shift.BeginSale(sku); break;
                case 5: shift.Scan(); break;
                case 6:
                    int reserved = shift.CustomerSku;
                    if (shift.Pay())
                    {
                        Check(reserved >= 0 && reserved < 3, "Payment requires a valid SKU.");
                        goods[reserved]--;
                        till += RetailShift.UnitPrice(reserved);
                        receipts++;
                    }
                    break;
            }
            if (step % 16 == 0) shift = Reload(shift);
            Check(shift.Cash == till && till >= 0 && shift.ReceiptCount == receipts, "Cash and receipt books diverged.");
            for (int i = 0; i < goods.Length; i++)
            {
                Check(Units(shift, i) == goods[i], "Stock disappeared or duplicated for SKU " + i + " on step " + step);
                Check(shift.GetShelf(i) >= 0 && shift.GetShelf(i) <= 6 && shift.GetDelivered(i) >= 0,
                    "Stock outside station capacity for SKU " + i);
            }
        }
        Check(receipts > 10, "The mixed shift should have completed at least ten real sales.");
    }

    public static void Main()
    {
        CheckTradingHours();
        CheckShelfAndTill();
        CheckCartons();
        CheckOrderValidation();
        CheckSaves();
        CheckMixedShift();
        Console.WriteLine($"{assertions:N0} checks passed across 8,000 randomized stock and till actions and 500 mid-shift save round-trips.");
    }
}
