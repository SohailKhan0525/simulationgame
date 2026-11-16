using System;
using UnityEngine;

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
        enum Station { None, Shelf, Tea, Cocoa, Soap, Checkout, Desk }
        enum Visit { Between, Entering, ToTill, Waiting, Leaving }

        [Serializable]
        sealed class Save
        {
            public RetailShift.Snapshot shift;
            public float minutes;
            public int day;
            public bool hasView;
            public Vector3 position;
            public float yaw, pitch;
        }

        static readonly Vector3 Outside = new Vector3(0, 0, -3.85f);
        static readonly Vector3 Aisle = new Vector3(-.15f, 0, 1.35f);
        static readonly Vector3 EndOfTill = new Vector3(.25f, 0, 2.98f);
        readonly Transform[] stock = new Transform[RetailShift.SkuCount * RetailShift.ShelfCapacity];
        readonly Transform[] cartons = new Transform[RetailShift.SkuCount];
        readonly Vector3[] receiving = new Vector3[RetailShift.SkuCount];
        readonly string[] names = new string[RetailShift.SkuCount];
        readonly int[] sizes = new int[RetailShift.SkuCount], costs = new int[RetailShift.SkuCount];
        readonly Vector3[] route = new Vector3[4];
        HarborBlock block;
        FirstPersonWalker controls;
        ShopInterface ui;
        Transform shelf, checkout, shopper, inHand, onBelt;
        MarketAudio audioCues;
        TextMesh tillReadout;
        ShopModels.WalkCycle gait;
        float stride, paidUntil;
        int lastPayment;
        float minutes = 17 * 60 + 20, arrivalDelay = 9, hudTimer, saveTimer;
        Vector3 startPosition = HarborBlock.Spawn;
        float startYaw, startPitch = 5;
        int day = 1, routeIndex, routeCount, beltSku = -1, cartonSku = -1, nextPreference;
        Visit visit;
        bool openingDesk;
        bool Trading => RetailShift.IsTradingAt(minutes);
        Station focus;
        public RetailShift Shift { get; private set; }
        public ShopInterface Interface => ui;
        public CharacterController Walker => controls.Controller;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void StartMarket()
        {
            if (FindFirstObjectByType<MarketSession>() == null)
                new GameObject("Harbor Market").AddComponent<MarketSession>();
        }

        void Awake()
        {
            Application.targetFrameRate = 60;
            Shift = new RetailShift();
            Restore();
            block = gameObject.AddComponent<HarborBlock>();
            block.SetHour(minutes / 60);
            shelf = Make(ShopModels.Shelf, HarborBlock.ShelfPosition);
            checkout = Make(ShopModels.Checkout, HarborBlock.CheckoutPosition);
            tillReadout = ShopModels.CreateTillReadout(checkout);
            Obstacle(shelf, new Vector3(0, .83f, .04f), new Vector3(1.78f, 1.66f, .57f));
            Obstacle(checkout, new Vector3(0, .48f, .03f), new Vector3(2.36f, .96f, .73f));
            for (int sku = 0; sku < RetailShift.SkuCount; sku++)
            {
                names[sku] = RetailShift.NameOf(sku);
                sizes[sku] = RetailShift.CaseSize(sku);
                costs[sku] = RetailShift.CaseCost(sku);
                // Cases stand along the receiving wall, each with a separate focus target.
                receiving[sku] = HarborBlock.DeliveryPosition + Vector3.forward * (sku - 1) * .66f;
                cartons[sku] = Make(ShopModels.Carton, receiving[sku]);
                cartons[sku].name = names[sku] + " receiving case";
                Obstacle(cartons[sku], new Vector3(0, .16f, 0), new Vector3(.51f, .32f, .46f));
                var sample = ShopModels.Product(cartons[sku], sku).transform;
                sample.localPosition = new Vector3(0, .344f, 0);
                for (int n = 0; n < RetailShift.ShelfCapacity; n++)
                {
                    int slot = sku * RetailShift.ShelfCapacity + n;
                    stock[slot] = ShopModels.Product(shelf, sku).transform;
                    stock[slot].localPosition = ShopModels.ShelfSlot(slot);
                }
            }
            shopper = Make(ShopModels.Customer, Outside);
            gait = ShopModels.ArticulateCustomer(shopper);
            shopper.gameObject.SetActive(false);
            controls = new GameObject("Shopkeeper").AddComponent<FirstPersonWalker>();
            controls.transform.SetParent(transform, false);
            controls.Place(startPosition, startYaw, startPitch);
            audioCues = gameObject.AddComponent<MarketAudio>();
            ui = new GameObject("Harbor Market UI").AddComponent<ShopInterface>();
            ui.transform.SetParent(transform, false);
            ui.Configure(Interact, Order, LeaveDesk);
            if (Shift.CustomerSku >= 0)
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
            float dt = Mathf.Min(Time.deltaTime, .15f);
            minutes += dt * 2f;
            if (minutes >= 1440) { minutes -= 1440; day++; }
            block.SetHour(minutes / 60);
            controls.Tick(dt, ui.DeskOpen);
            if (openingDesk && controls.AtDesk) ShowOrderPad();
            AdvanceVisit(dt);
            if (onBelt != null && Shift.Scanned)
                onBelt.localPosition = Vector3.MoveTowards(onBelt.localPosition, ShopModels.ScannerSpot, dt * 1.15f);
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
                if (!Trading) return;
                arrivalDelay -= dt;
                if (arrivalDelay > 0 || AvailableSku() < 0) return;
                shopper.gameObject.SetActive(true);
                shopper.position = Outside;
                SetRoute(Visit.Entering, new Vector3(0, 0, -.8f), HarborBlock.ShelfPosition + Vector3.back * .8f);
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
                if (sku >= 0 && Shift.BeginSale(sku))
                {
                    nextPreference = (sku + 1) % RetailShift.SkuCount;
                    SetRoute(Visit.ToTill, Aisle, EndOfTill, HarborBlock.CustomerPosition);
                    RefreshModels();
                    SaveShift();
                }
                else WalkOut();
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

        void WalkOut() => SetRoute(Visit.Leaving, EndOfTill, Aisle, new Vector3(0, 0, -.8f), Outside);

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
            if (station == Station.Shelf && Shift.HeldSku >= 0 && Shift.GetShelf(Shift.HeldSku) < RetailShift.ShelfCapacity)
                return "Stock shelf";
            if (station == Station.Checkout)
            {
                if (visit == Visit.Waiting) return Shift.Scanned ? "Take payment" : "Scan item";
                if (visit == Visit.Between && !Trading) return "Open at 08:00";
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
                    return visit == Visit.Waiting ? names[Shift.CustomerSku] + "   " + Money(RetailShift.UnitPrice(Shift.CustomerSku)) : Trading ? "Checkout" : "Shop closed";
                case Station.Shelf:
                    if (Shift.HeldSku >= 0)
                        return names[Shift.HeldSku] + "   " + Shift.GetShelf(Shift.HeldSku) + " / " + RetailShift.ShelfCapacity;
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
            if (ui.DeskOpen || openingDesk) return;
            focus = FindStation();
            if (ActionFor(focus).Length == 0) return;
            if (focus == Station.Desk) { OpenDesk(); return; }
            if (focus == Station.Checkout && visit == Visit.Between && !Trading)
            {
                if (minutes >= RetailShift.ClosingMinute) day++;
                minutes = RetailShift.OpeningMinute;
                arrivalDelay = 3;
                block.SetHour(8);
                ui.Notify("Open for the day");
                UpdateHud();
                SaveShift();
                return;
            }
            bool done;
            string notice;
            if (focus == Station.Shelf)
            {
                int sku = Shift.HeldSku, before = Shift.HeldUnits;
                done = Shift.Stock();
                notice = (before - Shift.HeldUnits) + " stocked · " + names[sku];
            }
            else if (focus == Station.Checkout)
            {
                int sku = Shift.CustomerSku;
                if (Shift.Scanned)
                {
                    done = Shift.Pay();
                    notice = "Card approved   " + Money(RetailShift.UnitPrice(sku));
                    if (done)
                    {
                        lastPayment = RetailShift.UnitPrice(sku);
                        paidUntil = Time.unscaledTime + 2.5f;
                        WalkOut();
                        audioCues.Paid();
                    }
                }
                else
                {
                    done = Shift.Scan();
                    notice = names[sku] + "   " + Money(RetailShift.UnitPrice(sku));
                    if (done) audioCues.Scan();
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

        void UpdateHud()
        {
            focus = FindStation();
            int time = (int)minutes;
            string clock = "Day " + day + "   " + (time / 60).ToString("00") + ":" + (time % 60).ToString("00");
            string held = Shift.HeldSku < 0 ? "" : names[Shift.HeldSku] + "   ×" + Shift.HeldUnits;
            ui.SetHud(clock, Money(Shift.Cash), Subject(focus), ActionFor(focus), held);
            string amount = paidUntil > Time.unscaledTime ? "PAID  " + Money(lastPayment) : Trading ? "READY" : "CLOSED";
            if (visit == Visit.Waiting)
                amount = Shift.Scanned ? "TOTAL  " + Money(RetailShift.UnitPrice(Shift.CustomerSku)) : "NEXT ITEM";
            if (tillReadout.text != amount) tillReadout.text = amount;
        }

        void RefreshModels()
        {
            for (int sku = 0; sku < RetailShift.SkuCount; sku++)
            {
                cartons[sku].gameObject.SetActive(Shift.GetDelivered(sku) > 0);
                for (int n = 0; n < RetailShift.ShelfCapacity; n++)
                    stock[sku * RetailShift.ShelfCapacity + n].gameObject.SetActive(n < Shift.GetShelf(sku));
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
            int visibleSku = visit == Visit.Waiting ? Shift.CustomerSku : -1;
            if (beltSku != visibleSku)
            {
                if (onBelt != null) Destroy(onBelt.gameObject);
                onBelt = null;
                beltSku = visibleSku;
                if (beltSku >= 0)
                {
                    onBelt = ShopModels.Product(checkout, beltSku).transform;
                    onBelt.localPosition = Shift.Scanned ? ShopModels.ScannerSpot : ShopModels.BeltSpot;
                }
            }
        }

        void SaveShift()
        {
            if (Shift == null) return;
            var save = new Save { shift = Shift.Capture(), minutes = minutes, day = day };
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

        void Restore()
        {
            if (!PlayerPrefs.HasKey(SaveKey)) return;
            try
            {
                var save = JsonUtility.FromJson<Save>(PlayerPrefs.GetString(SaveKey));
                if (save == null || save.day < 1 || !(save.minutes >= 0 && save.minutes < 1440)) return;
                if (!RetailShift.TryRestore(save.shift, out var restored)) return;
                Shift = restored; minutes = save.minutes; day = save.day;
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
