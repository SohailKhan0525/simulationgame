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
        int count = shift.GetShelf(sku) + shift.GetDelivered(sku) + (shift.HeldSku == sku ? shift.HeldUnits : 0);
        for (int i = 0; i < shift.BasketCount; i++) if (shift.BasketSkuAt(i) == sku) count++;
        return count;
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
        var opening = new RetailShift();
        Check(opening.Cash == 4000, "Opening float must be £40.");
        Check(opening.GetShelf(0) == 5 && opening.GetShelf(1) == 4 && opening.GetShelf(2) == 2,
            "A new shop opens with five teas, four cocoa packs and two soaps on display.");
        Check(opening.GetDelivered(0) == 3, "A tea case should be ready to collect.");
        var shift = LowStockShop();
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
        var shift = LowStockShop();
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

    private static RetailShift LowStockShop()
    {
        var state = new RetailShift().Capture();
        state.shelf = new[] { 1, 1, 0, 0, 0, 0 };
        Check(RetailShift.TryRestore(state, out var restored), "Set up the nearly empty stockroom.");
        return restored;
    }

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
        Check(restored.GetShelf(0) == 5, "Snapshots returned to a caller cannot mutate live inventory.");
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
        int[] goods = { 8, 4, 2 };
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

    private static void CheckPricesAndBaskets()
    {
        var shift = LowStockShop();
        Check(shift.BeginBasket(0, 0) && shift.BasketCount == 2, "First shopper buys tea and cocoa together.");
        Check(Units(shift, 0) == 4 && Units(shift, 1) == 1, "Both items remain accounted for during checkout.");
        Check(shift.BasketTotal == 575 && shift.CurrentItemPrice == 250, "Prices are locked when stock is picked.");
        Check(shift.ChangePrice(0, 1) && shift.Price(0) == 275, "Change the shelf ticket by 25 pence.");
        Check(shift.Scan() && shift.ScannedCount == 1 && shift.ScannedTotal == 250 &&
            shift.CustomerSku == 1 && shift.CurrentItemPrice == 325 && !shift.Pay(), "First scan cannot settle a two-item sale.");
        var saved = Reload(shift);
        Check(saved.Scan() && saved.Scanned && !saved.Scan(), "The final item can be scanned once after resuming.");
        Check(saved.Pay() && saved.Cash == 4575 && saved.TodaySales == 575 && saved.ReceiptCount == 1 &&
            saved.TodayReceipts == 1 && !saved.Pay(), "Raising a shelf price cannot change a reserved basket.");
        Check(!saved.WillBuy(8, 1) && !saved.ChangePrice(-1, 1) && !saved.ChangePrice(0, int.MaxValue),
            "Price and demand calls validate their input.");
        while (saved.ChangePrice(0, 1)) { }
        Check(saved.Price(0) == 400 && !saved.CanChangePrice(0, 1), "Premium cap is six 25p increments.");
        int buyers = 0;
        for (int seed = 0; seed < 1000; seed++) if (saved.WillBuy(0, seed)) buyers++;
        Check(buyers > 200 && buyers < 360, "High prices deter shoppers but still leave a market.");
        Check(saved.Take(0) && saved.Stock(), "Make tea available at the premium price.");
        int rejectedSeed = 0;
        while (saved.WillBuy(0, rejectedSeed)) rejectedSeed++;
        Check(!saved.BeginBasket(0, rejectedSeed) && saved.GetShelf(0) == 3, "A shopper who walks away consumes no goods.");
        while (saved.ChangePrice(0, -1)) { }
        Check(saved.Price(0) == 175 && !saved.CanChangePrice(0, -1) && saved.WillBuy(0, rejectedSeed),
            "Bargains attract the reluctant shopper and still yield a margin.");
        Check(saved.BeginBasket(0, 1) && saved.BasketCount == 3 && saved.BasketTotal == 525,
            "A shopper may buy multiple units when only one product is stocked.");
        Check(saved.Scan() && saved.Scan() && saved.Scan() && saved.Pay(), "Three units settle exactly once.");

        var tapped = new RetailShift();
        Check(tapped.BeginBasket(0, 0) && tapped.BasketSkuAt(1) == 1 && tapped.ChangePrice(1, 1),
            "Two different products are on the belt with separate agreed prices.");
        Check(!tapped.ScanAt(-1) && !tapped.ScanAt(2) && tapped.ScanAt(1) && tapped.ScannedTotal == 325 &&
            tapped.BasketSkuAt(0) == 1 && tapped.BasketSkuAt(1) == 0 && !tapped.ScanAt(0),
            "Tap the cocoa first; the scanned line retains its quoted price and cannot be tapped again.");
        tapped = Reload(tapped);
        Check(tapped.CurrentItemPrice == 250 && tapped.BasketTotal == 575 && tapped.Scan() && tapped.Pay() &&
            tapped.Cash == 4575, "Scan order survives reopening with the correct total.");
    }

    private static void CheckV1Migration()
    {
        const string oldSave = "{\"version\":1,\"cash\":3400,\"shelf\":[0,1,0],\"delivered\":[0,0,0]," +
            "\"heldSku\":0,\"heldUnits\":3,\"customerSku\":1,\"scanned\":true,\"receipts\":6}";
        var old = JsonSerializer.Deserialize<RetailShift.Snapshot>(oldSave, SaveOptions);
        Check(RetailShift.TryRestore(old, out var shift), "Load a save produced before lists, prices and upgrades existed.");
        Check(shift.Capture().version == 2 && shift.HeldUnits == 3 && shift.ReceiptCount == 6 && shift.TodayReceipts == 0 &&
            !shift.ContractSigned && shift.Capacity == 6 && !shift.HasStocker, "Legacy stock, progress and carton survive.");
        Check(shift.Capture().shelf.Length == RetailShift.SkuCount && shift.GetShelf(1) == 1 &&
            !shift.IsUnlocked(3) && shift.GetDelivered(5) == 0 && shift.Price(5) == 185,
            "A three-product save expands to the new catalog with untouched starter goods and unopened licences.");
        Check(shift.Scanned && shift.CustomerSku == 1 && shift.ScannedTotal == 325 && shift.Pay() && shift.Cash == 3725 &&
            !shift.Pay(), "An already scanned legacy item keeps its historical price and pays once.");
        old.scanned = false;
        Check(RetailShift.TryRestore(old, out var pending) && !pending.Pay() && pending.Scan() && pending.Pay(),
            "An unscanned legacy item remains unscanned on upgrade.");
        var broken = pending.Capture();
        broken.prices = new[] { 0, 0, 0 };
        Check(!RetailShift.TryRestore(broken, out _), "New saves must have valid prices.");
        broken = shift.Capture();
        broken.contractSigned = true;
        Check(!RetailShift.TryRestore(broken, out _), "A signed contract requires earned progression.");
        broken = shift.Capture();
        broken.todayOtherIncome = RetailShift.ContractBonus;
        Check(!RetailShift.TryRestore(broken, out _), "An unsigned store cannot invent a bonus.");
        var partial = new RetailShift();
        partial.BeginBasket(0, 0);
        broken = partial.Capture();
        broken.scannedCount = 3;
        Check(!RetailShift.TryRestore(broken, out _), "Reject impossible basket scan positions.");
        broken = partial.Capture();
        broken.agreedPrices[0] = -1;
        Check(!RetailShift.TryRestore(broken, out _), "Reject invalid price locks.");
        Check(partial.BasketTotal == 575, "Captured arrays cannot modify a live sale.");
    }

    private static void CheckLicensedGoods()
    {
        var opening = new RetailShift().Capture();
        opening.cash = 15000;
        Check(RetailShift.TryRestore(opening, out var shift), "Load sufficient earnings for all wholesale cases.");
        for (int sku = RetailShift.BaseSkuCount; sku < RetailShift.SkuCount; sku++)
        {
            Check(!shift.IsUnlocked(sku) && shift.CapacityFor(sku) == 0 && !shift.ChangePrice(sku, 1) &&
                !shift.WillBuy(sku, 0) && !shift.BeginBasket(sku, 0), "Unlicensed goods are unavailable.");
            var mixedOrder = new int[RetailShift.SkuCount];
            mixedOrder[0] = 1;
            mixedOrder[sku] = 1;
            Check(!shift.Order(mixedOrder) && shift.Cash == 15000 && shift.GetDelivered(0) == 3,
                "A locked line rejects the entire order without changing cash or stock.");
        }
        var corrupted = shift.Capture();
        corrupted.delivered[5] = 1;
        Check(!RetailShift.TryRestore(corrupted, out _), "Locked goods cannot appear in a loaded receiving room.");
        Check(shift.TryExpand() && shift.CapacityFor(0) == 12 && shift.CapacityFor(3) == 6,
            "The second fixture opens the grocery licence and doubles the original facings.");
        Check(shift.Order(new[] { 0, 0, 0, 2, 2, 2 }) && shift.Cash == 8100 && shift.TodayWholesale == 3900,
            "Buy two cases each of oats, coffee and tomatoes at the advertised wholesale prices.");
        int[] sizes = { 6, 4, 5 };
        int[] prices = { 165, 350, 185 };
        string[] names = { "Coast Oats", "Jetty Coffee", "Pier Tomatoes" };
        for (int i = 0; i < sizes.Length; i++)
        {
            int sku = RetailShift.BaseSkuCount + i;
            Check(shift.IsUnlocked(sku) && RetailShift.NameOf(sku) == names[i] && shift.Price(sku) == prices[i] &&
                RetailShift.CaseSize(sku) == sizes[i] && shift.GetDelivered(sku) == 2 * sizes[i],
                "Each licence delivers the named product, quantity and ticket.");
            Check(shift.Take(sku) && shift.Stock() && shift.Take(sku), "Open both of this product's cases.");
            if (sizes[i] < 6) Check(shift.Stock(), "Use the remaining space on the licensed shelf.");
            Check(!shift.Stock() && shift.GetShelf(sku) == 6 && shift.HeldUnits == 2 * sizes[i] - 6 && shift.ReturnCarton(),
                "Six facings are the limit for a licensed item and surplus goods stay in the case.");
        }
        Check(shift.TryHireStocker() && shift.Take(0) && shift.BeginBasket(3, 1) &&
            shift.BasketCount == 3 && shift.BasketTotal == 700, "One basket contains oats, coffee and tomatoes.");
        int before = Units(shift, 3);
        Check(shift.RestockOne() == 3 && shift.GetShelf(3) == 6 && Units(shift, 3) == before &&
            shift.HeldSku == 0, "The stocker fills an empty licensed facing without touching the held tea.");
        Check(shift.ScanAt(2) && shift.ScannedTotal == 185 && shift.ChangePrice(4, 1),
            "The belt scanner and shelf tickets support every licensed item.");
        shift = Reload(shift);
        Check(shift.Price(4) == 375 && shift.BasketTotal == 700 && shift.Scan() && shift.Scan() && shift.Pay() &&
            shift.TodaySales == 700 && shift.Cash == 4300, "Licensed inventory, locked prices and the receipt survive reload.");
        corrupted = shift.Capture();
        corrupted.shelf[4] = 7;
        Check(!RetailShift.TryRestore(corrupted, out _), "Expansion saves cannot overfill a licensed facing.");
        Check(shift.Order(new[] { 1, 0, 0 }), "The original three-item order API remains usable after expansion.");
    }

    private static void CheckCampaign()
    {
        var shift = new RetailShift();
        Check(!shift.CanSignContract && !shift.SignContract() && shift.RestockOne() == -1, "Staff and rewards start locked.");
        Check(shift.TryExpand() && shift.IsExpanded && shift.Capacity == 12 && shift.Cash == 1000 &&
            !shift.TryExpand() && !shift.TryHireStocker(), "Buy the second fixture once, within the available balance.");
        Check(shift.Order(new[] { 1, 0, 0 }) && shift.TodayWholesale == 450 && shift.TodayInvestment == 3000,
            "Daily books separate wholesale from fixtures.");
        for (int i = 0; i < 2; i++) Check(shift.Take(0) && shift.Stock(), "Fill the expanded display.");
        Check(shift.GetShelf(0) == 11, "Expanded facings hold more than the original six units.");
        shift.CloseDay();
        shift = Reload(shift);
        Check(shift.LastWholesale == 450 && shift.LastInvestment == 3000 && shift.TodayWholesale == 0 &&
            shift.TodayInvestment == 0 && shift.LastReceipts == 0 && shift.GetShelf(0) == 11,
            "Closing preserves the ledger, fixture and goods overnight.");

        // Reach the contract entirely through orders and sales, starting from the real opening float.
        for (int i = 0; i < 100 && (!shift.CanHireStocker || shift.ReceiptCount < RetailShift.ContractReceipts); i++)
        {
            if (shift.GetShelf(0) == 0)
                Check(shift.Order(new[] { 1, 0, 0 }) && shift.Take(0) && shift.Stock(), "Profits fund the next tea case.");
            Check(shift.BeginSale(0) && shift.Scan() && shift.Pay(), "Complete a paying sale on the way to the supply contract.");
        }
        Check(!shift.CanSignContract && shift.TryHireStocker() && !shift.TryHireStocker() && shift.CanSignContract,
            "Hire the stocker after earning funds; lifetime receipts unlock the contract.");
        int initial = shift.Cash;
        Check(shift.SignContract() && shift.Cash == initial + RetailShift.ContractBonus &&
            shift.TodayOtherIncome == RetailShift.ContractBonus && shift.ContractSigned, "Sign and record the one-time bonus.");
        shift = Reload(shift);
        Check(!shift.SignContract() && !shift.CanSignContract && shift.Cash == initial + RetailShift.ContractBonus,
            "Reopening prevents a duplicate signing bonus.");
        int sales = shift.TodaySales, orders = shift.TodayWholesale, receipts = shift.TodayReceipts;
        Check(shift.Order(new[] { 1, 1, 0 }) && shift.Take(1), "Bring in additional stock while carrying a cocoa carton.");
        int before = shift.GetShelf(0), delivered = shift.GetDelivered(0);
        Check(shift.RestockOne() == 0 && shift.GetShelf(0) == before + 1 && shift.GetDelivered(0) == delivered - 1 &&
            shift.HeldSku == 1 && shift.HeldUnits == 3 && shift.GetDelivered(1) == 0,
            "Staff transfer one loose unit from receiving and leave the player's carton untouched.");
        int balance = shift.Cash;
        shift.CloseDay();
        shift = Reload(shift);
        Check(shift.LastSales == sales && shift.LastReceipts == receipts && shift.LastWholesale == orders + 1050 &&
            shift.LastInvestment == RetailShift.StockerCost && shift.LastOtherIncome == RetailShift.ContractBonus &&
            shift.TodaySales == 0 && shift.TodayOtherIncome == 0 && shift.Cash == balance, "The closed report reconciles.");
        shift.CloseDay();
        Check(shift.LastOtherIncome == 0 && !shift.SignContract(), "A later quiet day cannot repeat the contract reward.");
    }

    public static void Main()
    {
        CheckTradingHours();
        CheckShelfAndTill();
        CheckCartons();
        CheckOrderValidation();
        CheckSaves();
        CheckPricesAndBaskets();
        CheckV1Migration();
        CheckLicensedGoods();
        CheckCampaign();
        CheckMixedShift();
        Console.WriteLine($"{assertions:N0} checks passed, including pricing, baskets, v1 migration, the supply contract, " +
            "8,000 randomized stock and till actions and 500 mid-shift save round-trips.");
    }
}
