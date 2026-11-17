using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Qofeno
{
    public sealed partial class ShopInterface
    {
        enum OfficePage { Orders, Prices, Growth, Accounts, Contract }
        static readonly string[] PageLabels = { "Orders", "Prices", "Store", "Accounts", "Contract" };
        static readonly string[] PageHeadings = { "Stock order", "Shelf prices", "Store improvements", "Shift accounts", "Harbor supply contract" };
        static readonly string[] LedgerLabels = { "Customer receipts", "Sales", "Wholesale orders", "Store improvements", "Contract income", "Cash movement" };

        readonly RectTransform[] officePages = new RectTransform[PageLabels.Length];
        readonly RectTransform[] activeTabs = new RectTransform[PageLabels.Length];
        readonly Button[] tabButtons = new Button[PageLabels.Length];
        readonly RectTransform[] orderRows = new RectTransform[SkuCount], priceRows = new RectTransform[SkuCount];
        RectTransform rangeSelector, pantryMark, coastalMark;
        bool coastalRange;
        int suppliedSkus;
        readonly Text[] sellingPrices = new Text[SkuCount], comparisons = new Text[SkuCount];
        readonly Button[] lowerPrice = new Button[SkuCount], raisePrice = new Button[SkuCount];
        readonly Button[] growthActions = new Button[2];
        readonly Text[] growthCaptions = new Text[2], growthStatus = new Text[2];
        readonly Text[] todayLedger = new Text[LedgerLabels.Length], previousLedger = new Text[LedgerLabels.Length], receiptAmounts = new Text[LedgerLabels.Length];
        readonly Text[] contractProgress = new Text[3];
        Text contractAction, contractNote;
        Button signContract;
        Text officeHeading, currentPeriod, previousPeriod, reportTitle;
        RectTransform officeContent, report;
        RetailShift shift;
        Action saveAndRefresh, onReportClosed;
        Func<int> readDay;
        OfficePage page;
        int confirmingPurchase = -1;
        float refreshOfficeAt;

        public bool ReportOpen => report != null && report.gameObject.activeSelf;

        public void ConfigureManagement(RetailShift market, Action saveAndRefresh, Func<int> readDay)
        {
            shift = market;
            this.saveAndRefresh = saveAndRefresh;
            this.readDay = readDay;
        }

        void BuildNavigation(RectTransform top)
        {
            for (int i = 0; i < PageLabels.Length; i++)
            {
                var target = (OfficePage)i;
                var button = TextButton(top, PageLabels[i], PageLabels[i], Pine, Chalk, () => SelectPage(target));
                Place(button.transform as RectTransform, 186 + i * 108, 0, 107, 60);
                activeTabs[i] = Row(button.transform as RectTransform, "Current page", 55, 5, Gold);
                tabButtons[i] = button;
            }
        }

        void BuildRangeSelector()
        {
            rangeSelector = Panel(officeContent, "Product range");
            Place(rangeSelector, 279, 69, 251, 49);
            var pantry = TextButton(rangeSelector, "Pantry range", "Pantry", Pale, Pine, () => SetRange(false));
            var coastal = TextButton(rangeSelector, "Coastal range", "Coastal", Pale, Pine, () => SetRange(true));
            Place(pantry.transform as RectTransform, 0, 0, 121, 49);
            Place(coastal.transform as RectTransform, 126, 0, 121, 49);
            pantryMark = Row(pantry.transform as RectTransform, "Selected", 45, 4, Pine);
            coastalMark = Row(coastal.transform as RectTransform, "Selected", 45, 4, Pine);
        }

        void SetRange(bool coastal)
        {
            coastalRange = coastal;
            SetVisible(pantryMark.gameObject, !coastal);
            SetVisible(coastalMark.gameObject, coastal);
            for (int sku = 0; sku < SkuCount; sku++)
            {
                bool show = (sku >= RetailShift.BaseSkuCount) == coastal;
                SetVisible(orderRows[sku].gameObject, show);
                SetVisible(priceRows[sku].gameObject, show);
            }
        }

        void BuildManagementPages(Texture2D prints, Texture2D coastalPrints)
        {
            var pricesPage = officePages[(int)OfficePage.Prices] = Panel(officeContent, "Pricing book");
            var heading = Row(pricesPage, "Price headings", 129, 28, Pale);
            At(heading, "Item", "Product", 16, Muted, true, 22, 1, 300, 25);
            At(heading, "Benchmark", "Local market", 16, Muted, true, 385, 1, 150, 25);
            At(heading, "Selling price heading", "Your shelf price", 16, Muted, true, 578, 1, 264, 25, TextAnchor.MiddleCenter);
            for (int sku = 0; sku < SkuCount; sku++)
                BuildPriceRow(pricesPage, sku, sku < RetailShift.BaseSkuCount ? prints : coastalPrints);
            Row(pricesPage, "Rule", 374, 2, Pine);
            At(pricesPage, "Pricing guidance", "Adjust in 25p steps. Prices above the local market can cost a sale.",
                19, Ink, false, 22, 388, 821, 50);

            var growth = officePages[(int)OfficePage.Growth] = Panel(officeContent, "Store improvement orders");
            BuildGrowthRow(growth, 0, "Second grocery shelf", "Adds 3 coastal products with 6 spaces each. Pantry space doubles.");
            BuildGrowthRow(growth, 1, "Stockroom assistant", "Moves delivered stock from receiving to available shelf space.");
            Row(growth, "Rule", 377, 2, Pine);

            var accounts = officePages[(int)OfficePage.Accounts] = Panel(officeContent, "Trading ledger");
            var columns = Row(accounts, "Ledger periods", 129, 36, Pale);
            At(columns, "Ledger heading", "Till ledger", 18, Muted, true, 22, 0, 310, 36);
            previousPeriod = At(columns, "Previous trading day", "Last close", 18, Muted, true, 362, 0, 199, 36, TextAnchor.MiddleRight);
            currentPeriod = At(columns, "Current trading day", "This shift", 18, Pine, true, 625, 0, 216, 36, TextAnchor.MiddleRight);
            for (int i = 0; i < LedgerLabels.Length; i++)
            {
                bool total = i == LedgerLabels.Length - 1;
                var row = Row(accounts, LedgerLabels[i], 165 + i * 44, total ? 58 : 44, total ? Pale : Paper);
                Row(row, "Ruling", 0, total ? 2 : 1, total ? Pine : Rule);
                At(row, "Account", LedgerLabels[i], total ? 26 : 20, Ink, total, 22, 2, 315, total ? 54 : 40);
                previousLedger[i] = At(row, "Previous", "", 22, Muted, true, 362, 2, 199, total ? 54 : 40, TextAnchor.MiddleRight);
                todayLedger[i] = At(row, "Current", "", total ? 29 : 24, Ink, true, 625, 2, 216, total ? 54 : 40, TextAnchor.MiddleRight);
            }
            BuildContract();
            BuildClosingReport();
        }

        void BuildPriceRow(RectTransform parent, int sku, Texture2D prints)
        {
            int index = sku % RetailShift.BaseSkuCount;
            var row = priceRows[sku] = Row(parent, RetailShift.NameOf(sku), 157 + index * 72, 72, Paper);
            if (index > 0) Row(row, "Rule", 0, 1, Rule);
            ProductThumbnail(row, sku, prints);
            At(row, "Product", RetailShift.NameOf(sku), 26, Ink, true, 78, 7, 288, 35);
            comparisons[sku] = At(row, "Price difference", "", 16, Muted, false, 79, 40, 285, 24);
            At(row, "Local market price", Money(RetailShift.UnitPrice(sku)), 24, Ink, true, 385, 7, 125, 57);
            lowerPrice[sku] = TextButton(row, "Lower shelf price", "−", Pale, Ink, () => AdjustPrice(sku, -1));
            Place(lowerPrice[sku].transform as RectTransform, 581, 6, 59, 60);
            sellingPrices[sku] = At(row, "Your price", "", 29, Ink, true, 643, 5, 137, 62, TextAnchor.MiddleCenter);
            raisePrice[sku] = TextButton(row, "Raise shelf price", "+", Pale, Ink, () => AdjustPrice(sku, 1));
            Place(raisePrice[sku].transform as RectTransform, 783, 6, 62, 60);
        }

        void BuildGrowthRow(RectTransform parent, int index, string title, string detail)
        {
            var row = Row(parent, title, 129 + index * 124, 124, Paper);
            Row(row, "Rule", 0, 1, Rule);
            At(row, "Improvement", title, 29, Ink, true, 22, 7, 492, 40);
            At(row, "Effect", detail, 18, Ink, false, 22, 48, 541, 31);
            growthStatus[index] = At(row, "Availability", "", 17, Muted, false, 22, 80, 540, 31);
            var purchase = Plate(row, title + " action", Pine, true);
            Place(purchase, 603, 28, 242, 64);
            growthActions[index] = MakeButton(purchase, Pine, () => Purchase(index));
            growthCaptions[index] = Label(purchase, "Action", "", 23, Chalk, true, TextAnchor.MiddleCenter);
        }

        void BuildContract()
        {
            var contract = officePages[(int)OfficePage.Contract] = Panel(officeContent, "Harbor supply contract");
            var heading = Row(contract, "Contract criteria", 129, 34, Pale);
            At(heading, "Criteria heading", "Supplier requirements", 18, Muted, true, 22, 0, 350, 34);
            At(heading, "Status heading", "Store progress", 18, Muted, true, 582, 0, 257, 34, TextAnchor.MiddleRight);
            string[] requirements = { "Serve " + RetailShift.ContractReceipts + " customers", "Install a second grocery shelf", "Hire a stockroom assistant" };
            for (int i = 0; i < requirements.Length; i++)
            {
                var row = Row(contract, requirements[i], 163 + i * 57, 57, Paper);
                Row(row, "Rule", 0, 1, Rule);
                At(row, "Requirement", requirements[i], 24, Ink, true, 22, 0, 481, 57);
                contractProgress[i] = At(row, "Progress", "", 21, Pine, true, 540, 0, 300, 57, TextAnchor.MiddleRight);
            }
            Row(contract, "Settlement rule", 337, 2, Pine);
            At(contract, "Signing bonus", "Signing bonus   " + Money(RetailShift.ContractBonus), 28, Ink, true, 22, 354, 495, 44);
            contractNote = At(contract, "Settlement status", "", 18, Muted, false, 22, 398, 520, 41);
            var action = Plate(contract, "Sign supply contract", Pine, true);
            Place(action, 601, 369, 242, 65);
            signContract = MakeButton(action, Pine, SignContract);
            contractAction = Label(action, "Signature", "", 23, Chalk, true, TextAnchor.MiddleCenter);
        }

        void SignContract()
        {
            if (!DeskOpen || page != OfficePage.Contract || !shift.SignContract()) return;
            saveAndRefresh?.Invoke();
            RefreshOffice();
        }

        void SelectPage(OfficePage target)
        {
            if (target != OfficePage.Orders && shift == null) return;
            page = target;
            confirmingPurchase = -1;
            officeHeading.text = PageHeadings[(int)page];
            bool catalog = target == OfficePage.Orders || target == OfficePage.Prices;
            SetVisible(rangeSelector.gameObject, catalog);
            if (catalog) SetRange(coastalRange);
            for (int i = 0; i < officePages.Length; i++)
            {
                bool visible = i == (int)page;
                SetVisible(officePages[i].gameObject, visible);
                SetVisible(activeTabs[i].gameObject, visible);
                tabButtons[i].interactable = i == 0 || shift != null;
            }
            RefreshOffice();
        }

        void RefreshOffice()
        {
            if (shift != null)
            {
                available = shift.Cash;
                fundsText.text = Money(available);
            }
            switch (page)
            {
                case OfficePage.Orders:
                    if (shift != null)
                        for (int i = 0; i < SkuCount; i++)
                            stockLabels[i].text = !shift.IsUnlocked(i) ? "Requires second shelf" :
                                (shift.GetShelf(i) + shift.GetDelivered(i) +
                                (shift.HeldSku == i ? shift.HeldUnits : 0)) + " in store";
                    RefreshCart();
                    break;
                case OfficePage.Prices:
                    for (int i = 0; i < SkuCount; i++)
                    {
                        int current = shift.Price(i);
                        int difference = current - RetailShift.UnitPrice(i);
                        sellingPrices[i].text = shift.IsUnlocked(i) ? Money(current) : "—";
                        comparisons[i].text = !shift.IsUnlocked(i) ? "Requires second shelf" : difference == 0 ? "At market price" :
                            Money(Math.Abs(difference)) + (difference < 0 ? " below market" : " above market");
                        lowerPrice[i].interactable = shift.CanChangePrice(i, -1);
                        raisePrice[i].interactable = shift.CanChangePrice(i, 1);
                    }
                    break;
                case OfficePage.Growth:
                    RefreshGrowth(0, shift.IsExpanded, RetailShift.ExpansionCost);
                    RefreshGrowth(1, shift.HasStocker, RetailShift.StockerCost);
                    break;
                case OfficePage.Accounts:
                    int day = readDay?.Invoke() ?? 1;
                    currentPeriod.text = "Day " + day + "  ·  current";
                    previousPeriod.text = day > 1 ? "Last close" : "No prior close";
                    FillLedger(todayLedger, shift.TodayReceipts, shift.TodaySales, shift.TodayWholesale, shift.TodayInvestment, shift.TodayOtherIncome);
                    if (day > 1)
                        FillLedger(previousLedger, shift.LastReceipts, shift.LastSales, shift.LastWholesale, shift.LastInvestment, shift.LastOtherIncome);
                    else foreach (var amount in previousLedger) amount.text = "—";
                    break;
                case OfficePage.Contract:
                    contractProgress[0].text = Math.Min(shift.ReceiptCount, RetailShift.ContractReceipts) + " / " + RetailShift.ContractReceipts + " served";
                    contractProgress[1].text = shift.IsExpanded ? "Installed" : "One shelf";
                    contractProgress[2].text = shift.HasStocker ? "On staff" : "Vacant";
                    signContract.interactable = shift.CanSignContract;
                    contractAction.text = shift.ContractSigned ? "Contract signed" : "Sign contract";
                    contractNote.text = shift.ContractSigned ? "Bonus paid. Your market stays open for trade." :
                        shift.CanSignContract ? "Your store qualifies. Sign to collect." : "Meet the three requirements to sign.";
                    break;
            }
        }

        void RefreshGrowth(int index, bool purchased, int cost)
        {
            bool affordable = available >= cost;
            bool canInvest = index == 0 ? shift.CanExpand : shift.CanHireStocker;
            growthActions[index].interactable = canInvest;
            string action = index == 0 ? "Install" : "Hire";
            growthCaptions[index].text = purchased ? (index == 0 ? "Installed" : "On staff") :
                (confirmingPurchase == index ? "Confirm   " : action + "   ") + Money(cost);
            growthStatus[index].text = purchased ? (index == 0 ? "In use on the shop floor" : "Working in receiving") :
                !affordable ? "Short by   " + Money(cost - available) :
                canInvest ? "Balance after purchase   " + Money(available - cost) : "Keep trading stock or enough cash for a case.";
        }

        void AdjustPrice(int sku, int step)
        {
            if (!DeskOpen || page != OfficePage.Prices || !shift.ChangePrice(sku, step)) return;
            saveAndRefresh?.Invoke();
            RefreshOffice();
        }

        void Purchase(int index)
        {
            if (!DeskOpen || page != OfficePage.Growth || !growthActions[index].interactable) return;
            if (confirmingPurchase == index)
            {
                bool purchased = index == 0 ? shift.TryExpand() : shift.TryHireStocker();
                confirmingPurchase = -1;
                if (purchased) saveAndRefresh?.Invoke();
            }
            else confirmingPurchase = index;
            RefreshOffice();
        }

        static string SignedMoney(long amount) => amount < 0 ? "−" + Money(-amount) : Money(amount);

        static void FillLedger(Text[] entries, int receipts, long sales, long wholesale, long investment, long otherIncome)
        {
            entries[0].text = receipts.ToString();
            entries[1].text = Money(sales);
            entries[2].text = SignedMoney(-wholesale);
            entries[3].text = SignedMoney(-investment);
            entries[4].text = Money(otherIncome);
            entries[5].text = SignedMoney(sales + otherIncome - wholesale - investment);
        }

        void BuildClosingReport()
        {
            // The receipt overlays the office paper while the register completes a shift.
            report = Plate(sheet, "Closing slip", Paper, true);
            var top = Row(report, "Receipt header", 0, 56, Pine);
            At(top, "Shop identity", "Harbor Market", 25, Chalk, true, 28, 0, 365, 56);
            At(top, "Source", "Till record", 19, Chalk, false, 618, 0, 224, 56, TextAnchor.MiddleRight);
            reportTitle = At(report, "Settlement title", "", 41, Ink, true, 28, 65, 808, 59);
            for (int i = 0; i < LedgerLabels.Length; i++)
            {
                bool total = i == LedgerLabels.Length - 1;
                var row = Row(report, LedgerLabels[i], 128 + i * 40, total ? 52 : 40, total ? Pale : Paper);
                Row(row, "Ruling", 0, total ? 2 : 1, total ? Pine : Rule);
                At(row, "Account", LedgerLabels[i], total ? 27 : 21, Ink, total, 28, 1, 487, total ? 49 : 36);
                receiptAmounts[i] = At(row, "Amount", "", total ? 30 : 24, Ink, true, 553, 1, 285, total ? 49 : 36, TextAnchor.MiddleRight);
            }
            var resume = TextButton(report, "Continue shift", "Back to shop", Pine, Chalk, DismissDayReport);
            Place(resume.transform as RectTransform, 599, 390, 243, 62);
            report.gameObject.SetActive(false);
        }

        public void ShowDayReport(int closedDay, Action continueShift)
        {
            if (shift == null) { continueShift?.Invoke(); return; }
            onReportClosed = continueShift;
            reportTitle.text = "Day " + closedDay + " closing slip";
            FillLedger(receiptAmounts, shift.LastReceipts, shift.LastSales, shift.LastWholesale, shift.LastInvestment, shift.LastOtherIncome);
            ResetThumb();
            SetVisible(hud.gameObject, false);
            SetVisible(desk.gameObject, true);
            SetVisible(officeContent.gameObject, false);
            SetVisible(report.gameObject, true);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
        }

        public void DismissDayReport()
        {
            if (!ReportOpen) return;
            SetVisible(report.gameObject, false);
            SetVisible(officeContent.gameObject, true);
            SetVisible(desk.gameObject, false);
            SetVisible(hud.gameObject, true);
            var resumed = onReportClosed;
            onReportClosed = null;
            resumed?.Invoke();
        }
    }
}
