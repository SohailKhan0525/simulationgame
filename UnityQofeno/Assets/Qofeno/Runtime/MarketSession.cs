using System;
using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Qofeno
{
    [DefaultExecutionOrder(30)]
    public sealed class MarketSession : MonoBehaviour
    {
        static string SaveKey
        {
            get
            {
#if UNITY_EDITOR
                if (UnityEditor.SessionState.GetBool("Qofeno.Smoke.Isolated", false)) return "harbor-market.smoke.v1";
#endif
                return "harbor-market.shift.v1";
            }
        }
        enum Station { None, Shelf, Annex, CoastalShelf, Checkout, Desk, Tea, Cocoa, Soap, Oats, Coffee, Tomatoes }
        enum Visit { Between, Entering, ToTill, Waiting, Leaving }

        [Serializable]
        sealed class Save
        {
            public RetailShift.Snapshot shift;
            public float minutes;
            public int day;
            public int businessDay, reportDay, visitorNumber;
            public HarborQueue.Snapshot queue;
            public VisitorSnapshot visitor;
            public bool hasView;
            public Vector3 position;
            public float yaw, pitch;
        }

        [Serializable]
        sealed class VisitorSnapshot
        {
            public int phase;
            public Vector3 position;
            public float heading;
            public Vector3[] remainingStops;
        }

        static readonly Vector3 Outside = new Vector3(0, 0, -3.85f);
        static readonly Vector3 Aisle = new Vector3(-.15f, 0, 1.35f);
        static readonly Vector3 EndOfTill = new Vector3(.25f, 0, 2.98f);
        static readonly Vector3 AnnexAisle = new Vector3(-.7f, 0, 3.25f);
        static readonly Vector3 Door = new Vector3(0, 0, -.8f);
        const int SlotsPerFixture = RetailShift.BaseSkuCount * RetailShift.ShelfCapacity;
        readonly Transform[] stock = new Transform[SlotsPerFixture * 3];
        readonly Transform[] belt = new Transform[RetailShift.MaxBasket];
        readonly int[] beltSkus = new int[RetailShift.MaxBasket];
        readonly int[] shelfPrices = new int[RetailShift.SkuCount];
        readonly Transform[] cartons = new Transform[RetailShift.SkuCount];
        readonly Vector3[] receiving = new Vector3[RetailShift.SkuCount];
        readonly string[] names = new string[RetailShift.SkuCount];
        readonly int[] sizes = new int[RetailShift.SkuCount], costs = new int[RetailShift.SkuCount];
        readonly Vector3[] route = new Vector3[4];
        HarborBlock block;
        FirstPersonWalker controls;
        ShopInterface ui;
        Transform shelf, secondShelf, coastalShelf, checkout, shopper, inHand;
        HarborQueue waitingLine;
        HarborQueue.Snapshot savedQueue;
        VisitorSnapshot savedVisitor;
        int tapFinger = -1;
        Vector2 tapOrigin;
        TillCashDrawer drawer;
        MarketAudio audioCues;
        TextMesh tillReadout;
        ShopModels.WalkCycle gait;
        float stride, paidUntil;
        int lastPayment;
        float minutes = RetailShift.OpeningMinute, arrivalDelay = 9, hudTimer, saveTimer;
        Vector3 startPosition = HarborBlock.Spawn;
        float startYaw, startPitch = 5;
        int day = 1, businessDay = 1, reportDay, visitorNumber, routeIndex, routeCount, cartonSku = -1, nextPreference;
        Visit visit;
        bool openingDesk;
        bool Trading => RetailShift.IsTradingAt(minutes);
        bool CashTender => Shift.ReceiptCount % 2 == 0;
        Station focus;
        public RetailShift Shift { get; private set; }
        public ShopInterface Interface => ui;
        public CharacterController Walker => controls.Controller;
        public bool IsReady { get; private set; }

        void Awake()
        {
            Application.targetFrameRate = 60;
            Shift = new RetailShift();
            Restore();
            controls = new GameObject("Shopkeeper").AddComponent<FirstPersonWalker>();
            controls.transform.SetParent(transform, false);
            controls.Place(startPosition, startYaw, startPitch);
            ui = new GameObject("Harbor Market UI").AddComponent<ShopInterface>();
            ui.transform.SetParent(transform, false);
        }

        IEnumerator Start()
        {
            // Present the camera and loading UI before constructing the procedural world.
            yield return null;
            try
            {
                ui.BuildControls();
                BuildMarket();
                ui.Configure(Interact, Order, LeaveDesk);
                ui.ConfigureManagement(Shift, OfficeChanged, () => businessDay);
                drawer = gameObject.AddComponent<TillCashDrawer>();
                ui.SetStartupMessage(null);
                IsReady = true;
                if (reportDay > 0) ShowReport();
            }
            catch (Exception error)
            {
                Debug.LogException(error, this);
                ui.SetStartupMessage("Harbor Market couldn’t open.\n" +
                    error.GetType().Name + " · v" + Application.version);
            }
        }

        void BuildMarket()
        {
            block = gameObject.AddComponent<HarborBlock>();
            block.Build(minutes / 60);
            shelf = BuildShelf(HarborBlock.ShelfPosition, 0);
            checkout = Make(ShopModels.Checkout, HarborBlock.CheckoutPosition);
            tillReadout = ShopModels.CreateTillReadout(checkout, block);
            Obstacle(checkout, new Vector3(0, .48f, .03f), new Vector3(2.36f, .96f, .73f));
            for (int sku = 0; sku < RetailShift.SkuCount; sku++)
            {
                names[sku] = RetailShift.NameOf(sku);
                sizes[sku] = RetailShift.CaseSize(sku);
                costs[sku] = RetailShift.CaseCost(sku);
                // Cases stand along the receiving wall, each with a separate focus target.
                int bay = sku % RetailShift.BaseSkuCount;
                float offset = sku < RetailShift.BaseSkuCount ? 0 : -.70f;
                receiving[sku] = HarborBlock.DeliveryPosition + new Vector3(offset, 0, (bay - 1) * .66f);
                cartons[sku] = Make(ShopModels.Carton, receiving[sku]);
                cartons[sku].name = names[sku] + " receiving case";
                Obstacle(cartons[sku], new Vector3(0, .16f, 0), new Vector3(.51f, .32f, .46f));
                var sample = ShopModels.Product(cartons[sku], sku).transform;
                sample.localPosition = new Vector3(0, .344f, 0);
            }
            shopper = Make(ShopModels.Customer, Outside);
            gait = ShopModels.ArticulateCustomer(shopper);
            gait.SetAppearance(visitorNumber);
            shopper.gameObject.SetActive(false);
            waitingLine = HarborQueue.Build(transform);
            waitingLine.Restore(savedQueue);
            audioCues = gameObject.AddComponent<MarketAudio>();
            if (!RestoreVisitor() && Shift.CustomerSku >= 0)
            {
                shopper.gameObject.SetActive(true);
                shopper.position = HarborBlock.CustomerPosition;
                shopper.rotation = Quaternion.identity;
                visit = Visit.Waiting;
            }
            RefreshModels();
            UpdateHud();
            if (!PlayerPrefs.HasKey(SaveKey)) ui.Notify("Lift a tea carton at receiving, on your left");
        }

        Transform BuildShelf(Vector3 position, int index)
        {
            var fixture = Make(ShopModels.Shelf, position);
            if (index != 0) fixture.name = "Annex shelf";
            Obstacle(fixture, new Vector3(0, .83f, .04f), new Vector3(1.78f, 1.66f, .57f));
            for (int slot = 0; slot < SlotsPerFixture; slot++)
            {
                int sku = slot / RetailShift.ShelfCapacity + (index == 2 ? RetailShift.BaseSkuCount : 0);
                var item = ShopModels.Product(fixture, sku).transform;
                item.localPosition = ShopModels.ShelfSlot(slot);
                stock[index * SlotsPerFixture + slot] = item;
            }
            return fixture;
        }

        Transform Make(Func<Transform, GameObject> factory, Vector3 position)
        {
            var result = factory(transform).transform;
            result.localPosition = position;
            return result;
        }

        static void Obstacle(Transform obj, Vector3 center, Vector3 size)
        {
            var box = obj.gameObject.AddComponent<BoxCollider>();
            box.center = center;
            box.size = size;
        }

        void Update()
        {
            if (!IsReady) return;
            if (drawer.IsOpen || ui.ReportOpen)
            {
                if (Input.GetKeyDown(KeyCode.Escape))
                {
                    if (drawer.IsOpen) drawer.Close();
                    else ui.DismissDayReport();
                }
                return;
            }
            float dt = Mathf.Min(Time.deltaTime, .15f);
            minutes += dt * 2f;
            if (minutes >= 1440) { minutes -= 1440; day++; }
            if (day > businessDay && minutes >= RetailShift.OpeningMinute &&
                !ui.DeskOpen && !openingDesk && visit == Visit.Between && !waitingLine.Occupied)
            {
                CloseBooks(day);
                return;
            }
            block.SetHour(minutes / 60);
            controls.Tick(dt, ui.DeskOpen);
            if (openingDesk && controls.AtDesk) ShowOrderPad();
            bool busyTill = visit == Visit.ToTill || visit == Visit.Waiting;
            waitingLine.Tick(dt, Trading && AvailableSku() >= 0, busyTill, NextVisitor());
            AdvanceVisit(dt);
            if (!ui.DeskOpen && !openingDesk) TapGroceries();
            for (int i = 0; i < Shift.ScannedCount; i++)
                if (belt[i]) belt[i].localPosition = Vector3.MoveTowards(belt[i].localPosition, BagSpot(i), dt * 1.35f);
            if (Shift.HasStocker) AdvanceStocker(dt);
            hudTimer -= dt;
            if (hudTimer <= 0) { UpdateHud(); hudTimer = .1f; }
            if (Input.GetKeyDown(KeyCode.Escape) && ui.DeskOpen) LeaveDesk();
            else if (Input.GetKeyDown(KeyCode.E) && !ui.DeskOpen) Interact();
            saveTimer += dt;
            if (saveTimer > 15) SaveShift();
        }

        void AdvanceVisit(float dt)
        {
            if (visit == Visit.Waiting) return;
            if (visit == Visit.Between)
            {
                if (waitingLine.TryTake(out var position, out int number))
                {
                    visitorNumber = number;
                    shopper.gameObject.SetActive(true);
                    shopper.position = position;
                    shopper.rotation = Quaternion.identity;
                    gait.SetAppearance(number);
                    if (ReserveBasket()) SetRoute(Visit.ToTill, HarborBlock.CustomerPosition);
                    else WalkOut();
                    SaveShift();
                    return;
                }
                if (waitingLine.Occupied) return;
                if (!Trading) return;
                arrivalDelay -= dt;
                if (arrivalDelay > 0 || AvailableSku() < 0) return;
                shopper.gameObject.SetActive(true);
                shopper.position = Outside;
                visitorNumber = NextVisitor();
                gait.SetAppearance(visitorNumber);
                int sku = AvailableSku();
                if (sku >= RetailShift.BaseSkuCount)
                    SetRoute(Visit.Entering, Door, Aisle, AnnexAisle, HarborBlock.CoastalShelfPosition + Vector3.back * .75f);
                else if (Shift.GetFacing(sku, false) == 0)
                    SetRoute(Visit.Entering, Door, Aisle, AnnexAisle);
                else SetRoute(Visit.Entering, Door, HarborBlock.ShelfPosition + Vector3.back * .8f);
                return;
            }

            Vector3 delta = route[routeIndex] - shopper.position;
            if (delta.sqrMagnitude > .003f)
            {
                shopper.position = Vector3.MoveTowards(shopper.position, route[routeIndex], dt * 1.15f);
                stride += dt * 6.6f;
                gait.Step(stride, 1f);
                shopper.rotation = Quaternion.RotateTowards(shopper.rotation, Quaternion.LookRotation(-delta.normalized), dt * 270);
                return;
            }
            if (++routeIndex < routeCount) return;
            if (visit == Visit.Entering)
            {
                int sku = AvailableSku();
                if (ReserveBasket())
                {
                    if (shopper.position.z > 3)
                        SetRoute(Visit.ToTill, AnnexAisle, EndOfTill, HarborBlock.CustomerPosition);
                    else SetRoute(Visit.ToTill, Aisle, EndOfTill, HarborBlock.CustomerPosition);
                    SaveShift();
                }
                else
                {
                    if (sku >= 0) ui.Notify("Shopper left · check your shelf prices");
                    if (shopper.position.z > 3) SetRoute(Visit.Leaving, AnnexAisle, Aisle, Door, Outside);
                    else SetRoute(Visit.Leaving, Door, Outside);
                }
            }
            else if (visit == Visit.ToTill)
            {
                visit = Visit.Waiting;
                shopper.rotation = Quaternion.identity;
                gait.Step(stride, 0f);
                RefreshModels();
                ui.Notify("Customer at the till");
            }
            else
            {
                visit = Visit.Between;
                arrivalDelay = 7;
                shopper.gameObject.SetActive(false);
            }
        }

        void SetRoute(Visit phase, params Vector3[] stops)
        {
            visit = phase;
            Array.Copy(stops, route, stops.Length);
            routeCount = stops.Length;
            routeIndex = 0;
        }

        void WalkOut() => SetRoute(Visit.Leaving, EndOfTill, Aisle, Door, Outside);

        static bool IsShelf(Station station) =>
            station == Station.Shelf || station == Station.Annex || station == Station.CoastalShelf;

        int NextVisitor() => visitorNumber == int.MaxValue ? 1 : visitorNumber + 1;

        bool ReserveBasket()
        {
            int sku = AvailableSku();
            if (sku < 0 || !Shift.BeginBasket(sku, unchecked(visitorNumber * 397 + day * 17))) return false;
            nextPreference = (sku + 1) % RetailShift.SkuCount;
            RefreshModels();
            return true;
        }

        int AvailableSku()
        {
            for (int i = 0; i < RetailShift.SkuCount; i++)
            {
                int sku = (nextPreference + i) % RetailShift.SkuCount;
                if (Shift.GetShelf(sku) > 0) return sku;
            }
            return -1;
        }

        Station FindStation()
        {
            Station best = Station.None;
            float score = float.MaxValue;
            Score(Station.Shelf, HarborBlock.ShelfPosition + Vector3.up * 1.08f, 2.75f, ref best, ref score);
            if (secondShelf)
            {
                Score(Station.Annex, secondShelf.position + Vector3.up * 1.08f, 2.75f, ref best, ref score);
                Score(Station.CoastalShelf, coastalShelf.position + Vector3.up * 1.08f, 2.75f, ref best, ref score);
            }
            Score(Station.Checkout, HarborBlock.CheckoutPosition + Vector3.up * 1.0f, 2.65f, ref best, ref score);
            Score(Station.Desk, HarborBlock.DeskPosition + Vector3.up * 1.05f, 2.45f, ref best, ref score);
            for (int sku = 0; sku < RetailShift.SkuCount; sku++)
            {
                if (Shift.GetDelivered(sku) == 0 && Shift.HeldSku != sku) continue;
                Score((Station)((int)Station.Tea + sku), receiving[sku] + Vector3.up * .4f, 2.45f, ref best, ref score);
            }
            return best;
        }

        void Score(Station candidate, Vector3 point, float reach, ref Station best, ref float previous)
        {
            Vector3 delta = point - controls.View.position;
            float distance = delta.magnitude;
            if (distance > reach || distance < .01f) return;
            float facing = Vector3.Dot(controls.View.forward, delta / distance);
            if (facing < .68f) return;
            float score = distance * .18f + (1 - facing) * 4;
            if (score < previous) { previous = score; best = candidate; }
        }

        string ActionFor(Station station)
        {
            if (station == Station.Desk) return "Use computer";
            if (IsShelf(station) && Shift.HeldSku >= 0 && Shift.GetFacing(Shift.HeldSku, station == Station.Annex) < RetailShift.ShelfCapacity)
            {
                bool coastal = Shift.HeldSku >= RetailShift.BaseSkuCount;
                if (coastal == (station == Station.CoastalShelf)) return "Stock shelf";
            }
            if (station == Station.Checkout)
            {
                if (visit == Visit.Waiting) return Shift.Scanned ? (CashTender ? "Count change" : "Take card") : "Scan item";
                if (visit == Visit.Between && !Trading && !waitingLine.Occupied) return "Open at 08:00";
            }
            int sku = (int)station - (int)Station.Tea;
            if (sku >= 0 && sku < RetailShift.SkuCount)
            {
                if (Shift.HeldSku == sku) return "Return carton";
                if (Shift.HeldSku == -1 && Shift.GetDelivered(sku) > 0) return "Lift carton";
            }
            return "";
        }

        string Subject(Station station)
        {
            switch (station)
            {
                case Station.Checkout:
                    if (visit != Visit.Waiting) return Trading ? "Checkout" : "Shop closed";
                    if (Shift.Scanned) return "Basket total   " + Money(Shift.BasketTotal);
                    return (Shift.ScannedCount + 1) + "/" + Shift.BasketCount + "  " + names[Shift.CustomerSku] + "  " + Money(Shift.CurrentItemPrice);
                case Station.Shelf:
                case Station.Annex:
                case Station.CoastalShelf:
                    if (Shift.HeldSku >= 0)
                        return names[Shift.HeldSku] + "   " + Shift.GetFacing(Shift.HeldSku, station == Station.Annex) + " / " + RetailShift.ShelfCapacity;
                    return "Grocery shelf";
                case Station.Desk: return "Supplier desk";
                case Station.None: return "";
                default:
                    int sku = (int)station - (int)Station.Tea;
                    return names[sku] + "   ·   " + Shift.GetDelivered(sku) + " in receiving";
            }
        }

        public void Interact()
        {
            if (!IsReady || ui.DeskOpen || openingDesk || drawer.IsOpen) return;
            focus = FindStation();
            if (ActionFor(focus).Length == 0) return;
            if (focus == Station.Desk) { OpenDesk(); return; }
            if (focus == Station.Checkout && visit == Visit.Between && !Trading)
            {
                if (minutes >= RetailShift.ClosingMinute) day++;
                minutes = RetailShift.OpeningMinute;
                arrivalDelay = 3;
                block.SetHour(8);
                CloseBooks(day);
                return;
            }
            bool done;
            string notice;
            if (IsShelf(focus))
            {
                int sku = Shift.HeldSku, before = Shift.HeldUnits;
                done = Shift.StockAt(focus == Station.Annex);
                notice = (before - Shift.HeldUnits) + " stocked · " + names[sku];
            }
            else if (focus == Station.Checkout)
            {
                if (Shift.Scanned)
                {
                    if (CashTender) drawer.Open(Shift.BasketTotal, TillCashDrawer.TenderFor(Shift.BasketTotal), SettleSale);
                    else SettleSale();
                    return;
                }
                else
                {
                    ScanLine(Shift.ScannedCount);
                    return;
                }
            }
            else
            {
                int sku = (int)focus - (int)Station.Tea;
                bool returning = Shift.HeldSku >= 0;
                done = returning ? Shift.ReturnCarton() : Shift.Take(sku);
                notice = returning ? "Carton returned" : names[sku] + "   ·   " + Shift.HeldUnits + " in carton";
            }
            if (!done) return;
            if (focus != Station.Checkout) audioCues.Stock();
            ui.Notify(notice);
            RefreshModels();
            SaveShift();
            UpdateHud();
        }

        void OpenDesk()
        {
            openingDesk = true;
            controls.DeskMode(true);
        }

        void ShowOrderPad()
        {
            openingDesk = false;
            var counts = new int[RetailShift.SkuCount];
            for (int i = 0; i < counts.Length; i++) counts[i] = Shift.GetShelf(i) + Shift.GetDelivered(i) + (Shift.HeldSku == i ? Shift.HeldUnits : 0);
            ui.OpenDesk(Money(Shift.Cash), names, sizes, costs, counts, Shift.Cash);
        }

        void Order(int[] cases)
        {
            if (!ui.DeskOpen) return;
            if (!Shift.Order(cases)) { ui.RejectOrder("Order declined · check funds and space in receiving"); return; }
            int count = 0;
            foreach (int quantity in cases) count += quantity;
            LeaveDesk();
            ui.Notify(count + (count == 1 ? " case delivered" : " cases delivered") + " to receiving");
            audioCues.Paid();
            RefreshModels();
            SaveShift();
        }

        void LeaveDesk()
        {
            ui.CloseDesk();
            controls.DeskMode(false);
            UpdateHud();
        }

        public static string Money(int pence) => "£" + (pence / 100) + "." + (pence % 100).ToString("00");

        void OfficeChanged()
        {
            RefreshModels();
            UpdateHud();
            SaveShift();
        }

        void SettleSale()
        {
            int total = Shift.BasketTotal;
            bool cash = CashTender;
            if (visit != Visit.Waiting || !Shift.Pay()) return;
            lastPayment = total;
            paidUntil = Time.unscaledTime + 2.5f;
            WalkOut();
            audioCues.Paid();
            ui.Notify((cash ? "Cash received   " : "Card approved   ") + Money(total));
            OfficeChanged();
        }

        // A short tap on a package scans it. Right-thumb drags still turn the camera.
        void TapGroceries()
        {
            if (Input.touchCount == 0 || visit != Visit.Waiting || Shift.Scanned ||
                Vector3.Distance(controls.View.position, checkout.position + Vector3.up) > 2.65f)
            {
                tapFinger = -1;
                return;
            }
            for (int i = 0; i < Input.touchCount; i++)
            {
                var touch = Input.GetTouch(i);
                if (touch.phase == TouchPhase.Began &&
                    (EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject(touch.fingerId)))
                {
                    tapFinger = touch.fingerId;
                    tapOrigin = touch.position;
                }
                if (touch.fingerId != tapFinger) continue;
                if (touch.phase == TouchPhase.Canceled || Vector2.Distance(touch.position, tapOrigin) > Screen.height * .023f)
                {
                    tapFinger = -1;
                    continue;
                }
                if (touch.phase != TouchPhase.Ended) continue;
                tapFinger = -1;
                var ray = Camera.main.ScreenPointToRay(touch.position);
                float nearest = 2.85f;
                if (Physics.Raycast(ray, out var hit, nearest)) nearest = hit.distance;
                int line = -1;
                for (int j = Shift.ScannedCount; j < Shift.BasketCount; j++)
                {
                    if (!belt[j]) continue;
                    var bounds = belt[j].GetComponent<MeshRenderer>().bounds;
                    bounds.Expand(.045f);
                    if (bounds.IntersectRay(ray, out float distance) && distance < nearest)
                    {
                        line = j;
                        nearest = distance;
                    }
                }
                if (line >= 0) ScanLine(line);
            }
        }

        void ScanLine(int index)
        {
            int next = Shift.ScannedCount;
            int sku = Shift.BasketSkuAt(index), price = Shift.BasketPriceAt(index);
            if (visit != Visit.Waiting || !Shift.ScanAt(index)) return;
            if (index != next)
            {
                var item = belt[index];
                belt[index] = belt[next];
                belt[next] = item;
                beltSkus[index] = beltSkus[next];
                beltSkus[next] = sku;
            }
            audioCues.Scan();
            ui.Notify(names[sku] + "   " + Money(price));
            OfficeChanged();
        }

        void CloseBooks(int nextDay)
        {
            if (nextDay > businessDay)
            {
                reportDay = businessDay;
                Shift.CloseDay();
                businessDay = nextDay;
            }
            UpdateHud();
            SaveShift();
            if (reportDay > 0) ShowReport();
        }

        void ShowReport()
        {
            ui.ShowDayReport(reportDay, () =>
            {
                reportDay = 0;
                SaveShift();
            });
        }

        void AdvanceStocker(float dt)
        {
            int sku = Trading ? Shift.NextRestockSku() : -1;
            bool annex = sku >= 0 && sku < RetailShift.BaseSkuCount &&
                Shift.GetFacing(sku, false) == RetailShift.ShelfCapacity;
            if (block.TickStocker(true, sku, annex, dt, out int placedSku, out bool placedAnnex) &&
                Shift.RestockAt(placedSku, placedAnnex))
            {
                RefreshModels();
                SaveShift();
            }
        }

        static Vector3 BagSpot(int index) => ShopModels.ScannerSpot + new Vector3(index * .16f, 0, index % 2 * .12f);

        void UpdateHud()
        {
            focus = FindStation();
            int time = (int)minutes;
            string clock = "Day " + day + "   " + (time / 60).ToString("00") + ":" + (time % 60).ToString("00");
            string held = Shift.HeldSku < 0 ? "" : names[Shift.HeldSku] + "   ×" + Shift.HeldUnits;
            ui.SetHud(clock, Money(Shift.Cash), Subject(focus), ActionFor(focus), held);
            string amount = paidUntil > Time.unscaledTime ? "PAID  " + Money(lastPayment) : Trading ? "READY" : "CLOSED";
            if (visit == Visit.Waiting)
                amount = Shift.Scanned ? "TOTAL  " + Money(Shift.BasketTotal) :
                    Shift.ScannedCount + "/" + Shift.BasketCount + "   " + Money(Shift.ScannedTotal);
            if (tillReadout.text != amount) tillReadout.text = amount;
        }

        void RefreshModels()
        {
            bool newShelf = Shift.IsExpanded && !secondShelf;
            if (newShelf)
            {
                block.SetReceivingExpanded(true);
                secondShelf = BuildShelf(HarborBlock.SecondShelfPosition, 1);
                coastalShelf = BuildShelf(HarborBlock.CoastalShelfPosition, 2);
                coastalShelf.name = "Coastal provisions";
            }
            bool priceChanged = false;
            for (int sku = 0; sku < RetailShift.SkuCount; sku++)
            {
                cartons[sku].gameObject.SetActive(Shift.GetDelivered(sku) > 0);
                priceChanged |= shelfPrices[sku] != Shift.Price(sku);
                shelfPrices[sku] = Shift.Price(sku);
                int units = Shift.GetFacing(sku, false);
                int overflow = Shift.GetFacing(sku, true);
                for (int n = 0; n < RetailShift.ShelfCapacity; n++)
                {
                    int slot = sku % RetailShift.BaseSkuCount * RetailShift.ShelfCapacity + n;
                    if (sku < RetailShift.BaseSkuCount)
                    {
                        stock[slot].gameObject.SetActive(n < units);
                        if (secondShelf) stock[SlotsPerFixture + slot].gameObject.SetActive(n < overflow);
                    }
                    else if (coastalShelf) stock[2 * SlotsPerFixture + slot].gameObject.SetActive(n < units);
                }
            }
            if (priceChanged || newShelf)
            {
                block.UpdateShelfPrices(shelf, shelfPrices);
                if (secondShelf) block.UpdateShelfPrices(secondShelf, shelfPrices);
                if (coastalShelf) block.UpdateShelfPrices(coastalShelf, shelfPrices, RetailShift.BaseSkuCount);
            }
            if (cartonSku != Shift.HeldSku)
            {
                if (inHand != null) Destroy(inHand.gameObject);
                cartonSku = Shift.HeldSku;
                if (cartonSku >= 0)
                {
                    inHand = ShopModels.Carton(controls.View).transform;
                    inHand.localPosition = new Vector3(.21f, -.38f, .58f);
                    inHand.localRotation = Quaternion.Euler(-8, -12, 0);
                    inHand.localScale = Vector3.one * .68f;
                    var sample = ShopModels.Product(inHand, cartonSku).transform;
                    sample.localPosition = new Vector3(-.05f, .344f, 0);
                }
            }
            for (int i = 0; i < belt.Length; i++)
            {
                int sku = visit == Visit.Waiting && i < Shift.BasketCount ? Shift.BasketSkuAt(i) : -1;
                if (belt[i] && sku != beltSkus[i])
                {
                    Destroy(belt[i].gameObject);
                    belt[i] = null;
                }
                beltSkus[i] = sku;
                if (sku < 0 || belt[i]) continue;
                belt[i] = ShopModels.Product(checkout, sku).transform;
                belt[i].localPosition = i < Shift.ScannedCount ? BagSpot(i) :
                    ShopModels.BeltSpot + new Vector3(.24f * (1 - i), 0, (i % 2) * .1f);
            }
        }

        void SaveShift()
        {
            if (!IsReady) return;
            var save = new Save { shift = Shift.Capture(), minutes = minutes, day = day,
                businessDay = businessDay, reportDay = reportDay, visitorNumber = visitorNumber,
                queue = waitingLine.Capture(), visitor = CaptureVisitor() };
            if (controls != null)
            {
                save.position = controls.transform.position;
                save.yaw = Mathf.Repeat(controls.Yaw, 360);
                save.pitch = controls.Pitch;
                save.hasView = ValidPosition(save.position);
            }
            PlayerPrefs.SetString(SaveKey, JsonUtility.ToJson(save));
            PlayerPrefs.Save();
            saveTimer = 0;
        }

        static bool ValidPosition(Vector3 p) =>
            Mathf.Abs(p.x) <= 65 && p.z >= -19 && p.z <= 4.9f && p.y >= -.65f && p.y <= 1.0f;

        VisitorSnapshot CaptureVisitor()
        {
            if (visit == Visit.Between || visit == Visit.Waiting) return null;
            int count = routeCount - routeIndex;
            if (count <= 0) return null;
            var remaining = new Vector3[count];
            Array.Copy(route, routeIndex, remaining, 0, count);
            return new VisitorSnapshot { phase = (int)visit, position = shopper.position,
                heading = shopper.eulerAngles.y, remainingStops = remaining };
        }

        bool RestoreVisitor()
        {
            var saved = savedVisitor;
            if (saved == null || !ValidPosition(saved.position) || !(saved.heading >= 0 && saved.heading <= 360) ||
                saved.remainingStops == null || saved.remainingStops.Length < 1 || saved.remainingStops.Length > route.Length)
                return false;
            var phase = (Visit)saved.phase;
            if (phase != Visit.Entering && phase != Visit.ToTill && phase != Visit.Leaving) return false;
            if ((phase == Visit.ToTill) != (Shift.BasketCount > 0)) return false;
            foreach (var stop in saved.remainingStops) if (!ValidPosition(stop)) return false;
            shopper.position = saved.position;
            shopper.rotation = Quaternion.Euler(0, saved.heading, 0);
            shopper.gameObject.SetActive(true);
            SetRoute(phase, saved.remainingStops);
            return true;
        }

        void Restore()
        {
            if (!PlayerPrefs.HasKey(SaveKey)) return;
            try
            {
                var save = JsonUtility.FromJson<Save>(PlayerPrefs.GetString(SaveKey));
                if (save == null || save.day < 1 || !(save.minutes >= 0 && save.minutes < 1440)) return;
                if (!RetailShift.TryRestore(save.shift, out var restored)) return;
                Shift = restored; minutes = save.minutes; day = save.day;
                businessDay = save.businessDay > 0 && save.businessDay <= day ? save.businessDay :
                    Mathf.Max(1, day - (minutes < RetailShift.OpeningMinute ? 1 : 0));
                reportDay = save.reportDay > 0 && save.reportDay < businessDay ? save.reportDay : 0;
                visitorNumber = Mathf.Max(0, save.visitorNumber);
                savedQueue = save.queue;
                savedVisitor = save.visitor;
                if (save.hasView && ValidPosition(save.position) &&
                    save.yaw >= 0 && save.yaw <= 360 && Mathf.Abs(save.pitch) <= 70)
                {
                    startPosition = save.position;
                    startYaw = save.yaw;
                    startPitch = save.pitch;
                }
            }
            catch (ArgumentException) { Debug.LogWarning("Could not read the saved market shift."); }
        }

        void OnApplicationPause(bool paused) { if (paused) SaveShift(); }
        void OnApplicationQuit() => SaveShift();
    }
}
