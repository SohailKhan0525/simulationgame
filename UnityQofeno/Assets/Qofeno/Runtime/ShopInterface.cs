using System;
using System.Globalization;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Qofeno
{
    /// <summary>The player's heads-up display and the market's wholesale ordering terminal.</summary>
    public sealed partial class ShopInterface : MonoBehaviour
    {
        const int SkuCount = RetailShift.SkuCount;
        const float PaperWidth = 870f;
        const float PaperHeight = 472f;
        static readonly Color32[] PackColors =
        {
            new Color32(39, 68, 55, 255), new Color32(122, 65, 45, 255), new Color32(188, 193, 147, 255),
            new Color32(192, 151, 77, 255), new Color32(44, 70, 65, 255), new Color32(172, 62, 41, 255)
        };
        static readonly Color Ink = new Color32(28, 49, 44, 255);
        static readonly Color Muted = new Color32(71, 93, 80, 255);
        static readonly Color Paper = new Color32(248, 246, 232, 255);
        static readonly Color Rule = new Color32(174, 183, 158, 255);
        static readonly Color Pale = new Color32(227, 232, 211, 255);
        static readonly Color Pine = new Color32(28, 71, 58, 255);
        static readonly Color Chalk = new Color32(253, 250, 232, 255);
        static readonly Color HudDark = new Color32(19, 35, 32, 222);
        static readonly Color Gold = new Color32(239, 196, 105, 255);

        Font regular, display;
        RectTransform safe, hud, desk, sheet, prompt, toast;
        RectTransform startup;
        Text startupText;
        RectTransform thumbBase, thumb, carry;
        Text clockText, balanceText, focusText, actionText, carryText, toastText;
        Text fundsText, orderSummary, orderAmount, submitLabel;
        Button send;
        readonly Text[] productNames = new Text[SkuCount], stockLabels = new Text[SkuCount],
            caseLabels = new Text[SkuCount], prices = new Text[SkuCount], counts = new Text[SkuCount];
        readonly Button[] subtract = new Button[SkuCount], add = new Button[SkuCount];
        readonly int[] cart = new int[SkuCount], caseSizes = new int[SkuCount], casePrices = new int[SkuCount];
        int available, thumbId = -1;
        Vector2 thumbStart;
        float toastUntil;
        Rect previousSafe;
        Vector2Int previousScreen;
        Action interact, exitDesk;
        Action<int[]> order;
        bool submitting;
        Sprite ring, disc;
        Texture2D ringTexture, discTexture;
        public bool DeskOpen => desk != null && desk.gameObject.activeSelf;

        void Awake()
        {
            regular = Resources.Load<Font>("ShopType/Barlow-Regular");
            if (regular == null) regular = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            display = Resources.Load<Font>("ShopType/BarlowCondensed-SemiBold");
            if (display == null) display = regular;
            var canvasObject = new GameObject("Market interface", typeof(RectTransform), typeof(Canvas),
                typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvasObject.transform.SetParent(transform, false);
            var canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 20;
            var scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(960, 540);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 1;
            if (EventSystem.current == null)
            {
                var events = new GameObject("Market input", typeof(EventSystem), typeof(StandaloneInputModule));
                events.transform.SetParent(canvasObject.transform, false);
            }

            safe = Panel(canvasObject.transform, "Safe area");
            startup = Plate(canvasObject.transform, "Market startup", Pine, true);
            startupText = Label(startup, "Startup status", "", 28, Chalk, true, TextAnchor.MiddleCenter);
            Inset(startupText.rectTransform, 40, 20, 40, 20);
            SetStartupMessage("Opening Harbor Market…");
        }

        public void BuildControls()
        {
            ring = MakeCircle(true, out ringTexture);
            disc = MakeCircle(false, out discTexture);
            hud = Panel(safe, "Shop floor");
            BuildHud();
            desk = Panel(safe, "Supplier terminal");
            BuildTerminal();
            desk.gameObject.SetActive(false);
            BuildToast();
            LayoutSafeArea();
        }

        public void Configure(Action interact, Action<int[]> order, Action exitDesk)
        {
            this.interact = interact;
            this.order = order;
            this.exitDesk = exitDesk;
        }

        public void SetStartupMessage(string message)
        {
            bool show = !string.IsNullOrEmpty(message);
            startupText.text = message ?? "";
            SetVisible(safe.gameObject, !show);
            SetVisible(startup.gameObject, show);
        }

        public void SetHud(string clock, string balance, string focus, string action, string carried)
        {
            clockText.text = clock ?? "";
            balanceText.text = balance ?? "";
            focusText.text = focus ?? "";
            actionText.text = action ?? "";
            carryText.text = carried ?? "";
            SetVisible(carryText.transform.parent.gameObject, !string.IsNullOrEmpty(carried));
            SetVisible(prompt.gameObject, !string.IsNullOrEmpty(action));
        }

        public void OpenDesk(string balance, string[] itemNames, int[] sizes, int[] casePricesCents,
            int[] stockCounts, int availableCents)
        {
            if (itemNames == null || sizes == null || casePricesCents == null || stockCounts == null ||
                itemNames.Length < RetailShift.BaseSkuCount || sizes.Length != itemNames.Length ||
                casePricesCents.Length != itemNames.Length || stockCounts.Length != itemNames.Length)
                throw new ArgumentException("The wholesale terminal requires a name, case size, price and stock count for each SKU.");
            available = Math.Max(0, availableCents);
            submitting = false;
            coastalRange = false;
            suppliedSkus = Math.Min(itemNames.Length, SkuCount);
            fundsText.text = balance ?? Money(available);
            for (var i = 0; i < SkuCount; i++)
            {
                cart[i] = 0;
                caseSizes[i] = i < suppliedSkus ? Math.Max(1, sizes[i]) : RetailShift.CaseSize(i);
                casePrices[i] = i < suppliedSkus ? Math.Max(0, casePricesCents[i]) : RetailShift.CaseCost(i);
                productNames[i].text = i < suppliedSkus ? itemNames[i] : RetailShift.NameOf(i);
                stockLabels[i].text = i < suppliedSkus ? stockCounts[i] + " in store" : "Requires second shelf";
                caseLabels[i].text = caseSizes[i] + " units / case";
                prices[i].text = Money(casePrices[i]);
            }
            ResetThumb();
            SetVisible(hud.gameObject, false);
            SetVisible(desk.gameObject, true);
            SelectPage(OfficePage.Orders);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
        }

        public void CloseDesk()
        {
            if (ReportOpen) { DismissDayReport(); return; }
            SetVisible(desk.gameObject, false);
            SetVisible(hud.gameObject, true);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
        }

        public void RejectOrder(string message)
        {
            submitting = false;
            if (DeskOpen) RefreshCart();
            Notify(message);
        }

        public void Notify(string message)
        {
            toastText.text = message ?? "";
            toastUntil = Time.unscaledTime + 3.5f;
            SetVisible(toast.gameObject, !string.IsNullOrEmpty(message));
        }

        void Update()
        {
            if (!safe.gameObject.activeSelf) return;
            LayoutSafeArea();
            if (toast.gameObject.activeSelf && Time.unscaledTime >= toastUntil) toast.gameObject.SetActive(false);
            if (Application.isMobilePlatform && !DeskOpen) TrackThumb();
            if (DeskOpen && !ReportOpen && shift != null && Time.unscaledTime >= refreshOfficeAt)
            {
                refreshOfficeAt = Time.unscaledTime + 1;
                RefreshOffice();
            }
        }

        void LayoutSafeArea()
        {
            var pixels = new Vector2Int(Screen.width, Screen.height);
            if (pixels.x <= 0 || pixels.y <= 0) return;
            var area = Screen.safeArea;
            if (area.width <= 0 || area.height <= 0) area = new Rect(0, 0, pixels.x, pixels.y);
            if (pixels == previousScreen && area == previousSafe) return;
            previousScreen = pixels;
            previousSafe = area;
            safe.anchorMin = new Vector2(area.xMin / pixels.x, area.yMin / pixels.y);
            safe.anchorMax = new Vector2(area.xMax / pixels.x, area.yMax / pixels.y);
            safe.offsetMin = safe.offsetMax = Vector2.zero;
            var unit = 540f / pixels.y;
            bool compact = area.width * unit < 750;
            Pin(carry, .5f, 0, 0, compact ? 100 : 17, 245, 35, .5f, 0);
            float scale = Mathf.Min((area.width * unit - 18) / PaperWidth, (area.height * unit - 14) / PaperHeight);
            sheet.localScale = Vector3.one * Mathf.Clamp(scale, .1f, 1.3f);
        }

        void BuildHud()
        {
            var shift = Plate(hud, "Shift clock", HudDark);
            Pin(shift, 0, 1, 16, -16, 164, 40, 0, 1);
            clockText = Label(shift, "Clock", "", 22, Chalk, true);
            Inset(clockText.rectTransform, 12, 2, 10, 2);
            var wallet = Plate(hud, "Till balance", HudDark);
            Pin(wallet, 1, 1, -16, -16, 130, 40, 1, 1);
            balanceText = Label(wallet, "Balance", "", 22, Chalk, true, TextAnchor.MiddleRight);
            Inset(balanceText.rectTransform, 10, 2, 12, 2);

            var aimBorder = Plate(hud, "Aim rim", new Color32(14, 24, 22, 170), false, disc);
            Pin(aimBorder, .5f, .5f, 0, 0, 6, 6);
            var aim = Plate(aimBorder, "Aim point", Chalk, false, disc);
            Pin(aim, .5f, .5f, 0, 0, 3, 3);
            thumbBase = Plate(hud, "Move stick", new Color32(255, 255, 240, 102), false, ring);
            thumb = Plate(thumbBase, "Thumb", new Color32(255, 255, 240, 108), false, disc);
            Pin(thumb, .5f, .5f, 0, 0, 26, 26);
            ResetThumb();
            thumbBase.gameObject.SetActive(Application.isMobilePlatform);

            carry = Plate(hud, "Carried stock", HudDark);
            Pin(carry, .5f, 0, 0, 17, 245, 35, .5f, 0);
            carryText = Label(carry, "Carried item", "", 17, Chalk, false, TextAnchor.MiddleCenter);
            Inset(carryText.rectTransform, 7, 0, 7, 0);
            carry.gameObject.SetActive(false);
            prompt = Plate(hud, "Interact", HudDark, true);
            Pin(prompt, 1, 0, -18, 18, 210, 72, 1, 0);
            MakeButton(prompt, HudDark, () => interact?.Invoke());
            var edge = Plate(prompt, "Interaction mark", Gold);
            Pin(edge, 0, .5f, 0, 0, 4, 44, 0, .5f);
            focusText = At(prompt, "Target", "", 15, new Color32(217, 228, 209, 255), false, 16, 6, 180, 23);
            actionText = At(prompt, "Action", "", 27, Chalk, true, 16, 24, 183, 41);
            prompt.gameObject.SetActive(false);
        }

        void BuildTerminal()
        {
            Plate(desk, "Monitor surround", new Color32(13, 31, 28, 241), true);
            sheet = Plate(desk, "Supplier order form", Paper, true);
            Pin(sheet, .5f, .5f, 0, 0, PaperWidth, PaperHeight);
            officeContent = Panel(sheet, "Office pages");
            var top = Row(officeContent, "Terminal bar", 0, 60, Pine);
            At(top, "Terminal identity", "Harbor Market", 24, Chalk, true, 22, 0, 173, 60);
            VRule(top, 181, 20, 20, new Color32(135, 164, 139, 255));
            BuildNavigation(top);
            var leave = TextButton(top, "Leave desk", "Leave desk", new Color32(48, 90, 74, 255),
                Chalk, () => exitDesk?.Invoke());
            Place(leave.transform as RectTransform, 733, 0, 136, 60);

            officeHeading = At(officeContent, "Office page heading", "Stock order", 43, Ink, true, 22, 61, 442, 58);
            At(officeContent, "Funds caption", "Available funds", 16, Muted, false, 566, 70, 150, 32,
                TextAnchor.MiddleRight);
            fundsText = At(officeContent, "Available balance", "", 28, Ink, true, 721, 65, 126, 43,
                TextAnchor.MiddleRight);
            BuildRangeSelector();
            var orders = Panel(officeContent, "Stock order");
            officePages[(int)OfficePage.Orders] = orders;
            var headings = Row(orders, "Column headings", 129, 28, Pale);
            At(headings, "Product label", "Product", 16, Muted, true, 22, 1, 300, 25);
            At(headings, "Case label", "Pack size", 16, Muted, true, 354, 1, 145, 25);
            At(headings, "Price label", "Case price", 16, Muted, true, 511, 1, 105, 25);
            At(headings, "Quantity label", "Cases to order", 16, Muted, true, 648, 1, 197, 25, TextAnchor.MiddleCenter);
            var prints = Resources.Load<Texture2D>("ShopModels/harbor-prints");
            var coastalPrints = Resources.Load<Texture2D>(ShopModels.CoastalPrints);
            for (var i = 0; i < SkuCount; i++)
                BuildOrderRow(orders, i, i < RetailShift.BaseSkuCount ? prints : coastalPrints);
            Row(orders, "Footer rule", 373, 2, Pine);
            orderSummary = At(orders, "Order summary", "", 23, Ink, true, 22, 381, 468, 40);
            orderAmount = At(orders, "Balance after order", "", 17, Muted, false, 22, 418, 480, 35);
            var submitRect = Plate(orders, "Place order", Pine, true);
            Place(submitRect, 603, 389, 244, 64);
            send = MakeButton(submitRect, Pine, Submit);
            submitLabel = Label(submitRect, "Order total", "", 25, Chalk, true, TextAnchor.MiddleCenter);
            Inset(submitLabel.rectTransform, 6, 0, 6, 0);
            BuildManagementPages(prints, coastalPrints);
        }

        void BuildOrderRow(RectTransform orders, int sku, Texture2D prints)
        {
            int index = sku % RetailShift.BaseSkuCount;
            var row = orderRows[sku] = Row(orders, "Order line " + (sku + 1), 157 + index * 72, 72, Paper);
            if (index > 0) Row(row, "Line", 0, 1, Rule);
            ProductThumbnail(row, sku, prints);
            productNames[sku] = At(row, "Product name", "", 26, Ink, true, 78, 7, 264, 35);
            stockLabels[sku] = At(row, "Shelf stock", "", 16, Muted, false, 79, 40, 260, 24);
            caseLabels[sku] = At(row, "Case contents", "", 20, Ink, false, 354, 7, 150, 57);
            prices[sku] = At(row, "Case price", "", 25, Ink, true, 511, 7, 120, 57);
            subtract[sku] = TextButton(row, "Remove case", "−", Pale, Ink, () => Step(sku, -1));
            Place(subtract[sku].transform as RectTransform, 648, 5, 62, 62);
            counts[sku] = At(row, "Cases", "0", 27, Ink, true, 710, 7, 73, 58, TextAnchor.MiddleCenter);
            add[sku] = TextButton(row, "Add case", "+", Pale, Ink, () => Step(sku, 1));
            Place(add[sku].transform as RectTransform, 783, 5, 62, 62);
        }

        static void ProductThumbnail(RectTransform row, int sku, Texture2D prints)
        {
            var body = Plate(row, "Product pack", PackColors[sku]);
            float width = sku == 2 ? 44 : sku == 4 ? 39 : 34;
            float height = sku == 2 ? 35 : 51;
            Place(body, 43 - width * .5f, 36 - height * .5f, width, height);
            if (prints != null)
            {
                var graphic = Panel(body, "Printed label").gameObject.AddComponent<RawImage>();
                graphic.texture = prints;
                graphic.uvRect = sku >= RetailShift.BaseSkuCount ? ShopModels.CoastalLabelUV(sku) :
                    new Rect((8f + sku * 256) / 1024f, 716f / 1024f, 240f / 1024f, 300f / 1024f);
                graphic.raycastTarget = false;
                Inset(graphic.rectTransform, 2, 3, 2, 3);
            }
            if (sku == 1 || sku == 5)
            {
                Row(body, "Tin lid", 0, 3, Gold);
                Row(body, "Tin base", height - 3, 3, Gold);
            }
        }

        void Step(int sku, int direction)
        {
            if (submitting || !DeskOpen) return;
            if (direction > 0 && !CanAddCase(sku, Total())) return;
            cart[sku] = Math.Max(0, cart[sku] + direction);
            RefreshCart();
        }

        bool CanAddCase(int sku, long total)
        {
            if (sku >= suppliedSkus || total + casePrices[sku] > available || cart[sku] == int.MaxValue) return false;
            if (shift != null && !shift.IsUnlocked(sku)) return false;
            if (shift == null) return true;
            int delivered = shift.GetDelivered(sku) + (shift.HeldSku == sku ? shift.HeldUnits : 0);
            return ((long)cart[sku] + 1) * caseSizes[sku] <= RetailShift.DeliveryCapacity - delivered;
        }

        long Total()
        {
            long result = 0;
            for (var i = 0; i < SkuCount; i++) result += (long)cart[i] * casePrices[i];
            return result;
        }

        void RefreshCart()
        {
            long cases = 0, units = 0, total = Total();
            for (var i = 0; i < SkuCount; i++)
            {
                cases += cart[i];
                units += (long)cart[i] * caseSizes[i];
                counts[i].text = cart[i].ToString();
                subtract[i].interactable = !submitting && cart[i] > 0;
                add[i].interactable = !submitting && CanAddCase(i, total);
            }
            orderSummary.text = cases == 0 ? "No cases selected" :
                cases + (cases == 1 ? " case" : " cases") + "   /   " + units + (units == 1 ? " unit" : " units");
            orderAmount.text = total > available ? "Short by   " + Money(total - available) : "Balance after order   " + Money(available - total);
            submitLabel.text = "Place order   " + Money(total);
            send.interactable = !submitting && cases > 0 && total <= available;
        }

        void Submit()
        {
            if (!DeskOpen || submitting || !send.interactable || order == null) return;
            submitting = true;
            RefreshCart();
            try
            {
                var requested = new int[suppliedSkus];
                Array.Copy(cart, requested, requested.Length);
                order(requested);
            }
            finally
            {
                submitting = false;
                if (DeskOpen) RefreshCart();
            }
        }

        void BuildToast()
        {
            toast = Plate(safe, "Register message", HudDark);
            Pin(toast, .5f, 1, 0, -16, 358, 45, .5f, 1);
            toastText = Label(toast, "Message", "", 20, Chalk, false, TextAnchor.MiddleCenter);
            Inset(toastText.rectTransform, 9, 0, 9, 0);
            toast.gameObject.SetActive(false);
        }

        void TrackThumb()
        {
            for (var i = 0; i < Input.touchCount; i++)
            {
                var touch = Input.GetTouch(i);
                if (thumbId < 0 && touch.phase == TouchPhase.Began && touch.position.x < Screen.width * .5f)
                {
                    thumbId = touch.fingerId;
                    thumbStart = touch.position;
                    RectTransformUtility.ScreenPointToLocalPointInRectangle(safe, thumbStart, null, out var center);
                    Pin(thumbBase, .5f, .5f, center.x, center.y, 86, 86);
                }
                if (thumbId != touch.fingerId) continue;
                if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled) ResetThumb();
                else
                {
                    var drag = (touch.position - thumbStart) * (540f / Mathf.Max(1, Screen.height));
                    thumb.anchoredPosition = Vector2.ClampMagnitude(drag, 30);
                }
            }
            if (Input.touchCount == 0 && thumbId >= 0) ResetThumb();
        }

        void ResetThumb()
        {
            thumbId = -1;
            Pin(thumbBase, 0, 0, 86, 76, 86, 86);
            thumb.anchoredPosition = Vector2.zero;
        }

        static string Money(long cents) => "£" + (cents / 100m).ToString("0.00", CultureInfo.InvariantCulture);

        static void SetVisible(GameObject obj, bool show)
        {
            if (obj.activeSelf != show) obj.SetActive(show);
        }

        static RectTransform Panel(Transform parent, string name)
        {
            var rect = new GameObject(name, typeof(RectTransform)).GetComponent<RectTransform>();
            rect.SetParent(parent, false);
            Inset(rect, 0, 0, 0, 0);
            return rect;
        }

        static RectTransform Plate(Transform parent, string name, Color color, bool interactive = false, Sprite shape = null)
        {
            var rect = Panel(parent, name);
            var image = rect.gameObject.AddComponent<Image>();
            image.color = color;
            image.sprite = shape;
            image.raycastTarget = interactive;
            return rect;
        }

        Text Label(Transform parent, string name, string value, int size, Color color, bool condensed,
            TextAnchor alignment = TextAnchor.MiddleLeft)
        {
            var label = Panel(parent, name).gameObject.AddComponent<Text>();
            label.font = condensed ? display : regular;
            label.text = value;
            label.fontSize = size;
            label.color = color;
            label.alignment = alignment;
            label.horizontalOverflow = HorizontalWrapMode.Wrap;
            label.verticalOverflow = VerticalWrapMode.Truncate;
            label.resizeTextForBestFit = true;
            label.resizeTextMinSize = Math.Max(12, size - 6);
            label.resizeTextMaxSize = size;
            label.supportRichText = false;
            label.raycastTarget = false;
            return label;
        }

        Text At(Transform parent, string name, string value, int size, Color color, bool condensed,
            float x, float y, float w, float h, TextAnchor alignment = TextAnchor.MiddleLeft)
        {
            var text = Label(parent, name, value, size, color, condensed, alignment);
            Place(text.rectTransform, x, y, w, h);
            return text;
        }

        Button TextButton(Transform parent, string name, string value, Color fill, Color textColor, Action press)
        {
            var rect = Plate(parent, name, fill, true);
            var button = MakeButton(rect, fill, press);
            Label(rect, "Caption", value, value == "+" || value == "−" ? 30 : 21,
                textColor, true, TextAnchor.MiddleCenter);
            return button;
        }

        static Button MakeButton(RectTransform rect, Color fill, Action press)
        {
            var image = rect.GetComponent<Image>();
            image.color = Color.white;
            var button = rect.gameObject.AddComponent<Button>();
            button.targetGraphic = image;
            var colors = button.colors;
            colors.normalColor = fill;
            colors.selectedColor = Color.Lerp(fill, Gold, .38f);
            colors.highlightedColor = Color.Lerp(fill, Gold, .22f);
            colors.pressedColor = Color.Lerp(fill, Ink, .28f);
            colors.disabledColor = fill.grayscale > .5f ? Color.Lerp(fill, Paper, .85f) :
                new Color32(98, 114, 103, 255);
            colors.fadeDuration = .065f;
            button.colors = colors;
            button.onClick.AddListener(() => press());
            // Keep an already-enabled button in its initial visual state this frame.
            image.canvasRenderer.SetColor(colors.normalColor);
            return button;
        }

        static RectTransform Row(RectTransform parent, string name, float y, float height, Color color)
        {
            var row = Plate(parent, name, color);
            row.anchorMin = new Vector2(0, 1);
            row.anchorMax = Vector2.one;
            row.pivot = new Vector2(.5f, 1);
            row.sizeDelta = new Vector2(0, height);
            row.anchoredPosition = new Vector2(0, -y);
            return row;
        }

        static void VRule(Transform parent, float x, float y, float h, Color color)
            => Place(Plate(parent, "Divider", color), x, y, 1, h);

        static void Inset(RectTransform rect, float left, float top, float right, float bottom)
        {
            rect.anchorMin = Vector2.zero;
            rect.anchorMax = Vector2.one;
            rect.offsetMin = new Vector2(left, bottom);
            rect.offsetMax = new Vector2(-right, -top);
        }

        static void Place(RectTransform rect, float x, float top, float width, float height)
            => Pin(rect, 0, 1, x, -top, width, height, 0, 1);

        static void Pin(RectTransform rect, float ax, float ay, float x, float y, float width, float height,
            float px = .5f, float py = .5f)
        {
            rect.anchorMin = rect.anchorMax = new Vector2(ax, ay);
            rect.pivot = new Vector2(px, py);
            rect.sizeDelta = new Vector2(width, height);
            rect.anchoredPosition = new Vector2(x, y);
        }

        static Sprite MakeCircle(bool outline, out Texture2D texture)
        {
            const int size = 128;
            texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.name = outline ? "Stick ring" : "Aim disc";
            texture.wrapMode = TextureWrapMode.Clamp;
            texture.filterMode = FilterMode.Bilinear;
            var pixels = new Color32[size * size];
            for (var y = 0; y < size; y++)
            for (var x = 0; x < size; x++)
            {
                float radius = Vector2.Distance(new Vector2(x + .5f, y + .5f), new Vector2(64, 64));
                float alpha = Mathf.Clamp01(63.5f - radius);
                if (outline) alpha *= Mathf.Clamp01(radius - 60f);
                pixels[y * size + x] = new Color32(255, 255, 255, (byte)(alpha * 255f));
            }
            texture.SetPixels32(pixels);
            texture.Apply(false, true);
            return Sprite.Create(texture, new Rect(0, 0, size, size), new Vector2(.5f, .5f),
                100f, 0, SpriteMeshType.FullRect);
        }

        void OnDestroy()
        {
            if (ring != null) Destroy(ring);
            if (disc != null) Destroy(disc);
            if (ringTexture != null) Destroy(ringTexture);
            if (discTexture != null) Destroy(discTexture);
        }
    }
}
