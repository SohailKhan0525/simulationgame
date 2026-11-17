using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Qofeno
{
    /// <summary>A till tender is only committed when the cashier hands over exact change.</summary>
    public sealed class TillCashDrawer : MonoBehaviour
    {
        const float Width = 760f;
        const float Height = 432f;
        static readonly int[] Pence = { 1000, 500, 200, 100, 50, 20, 10, 5, 2, 1 };
        static readonly Color Case = new Color32(42, 54, 51, 255);
        static readonly Color Well = new Color32(25, 35, 33, 255);
        static readonly Color Paper = new Color32(246, 242, 225, 255);
        static readonly Color Ink = new Color32(29, 54, 44, 255);
        static readonly Color Soft = new Color32(190, 204, 191, 255);
        static readonly Color Brass = new Color32(248, 209, 123, 255);
        static readonly Color Copper = new Color32(204, 138, 97, 255);
        static readonly Color Silver = new Color32(198, 206, 199, 255);

        readonly Stack<int> picks = new Stack<int>();
        readonly int[] quantities = new int[Pence.Length];
        readonly Text[] quantitiesText = new Text[Pence.Length];
        RectTransform overlay, drawer;
        Font plain, narrow;
        Text totalText, tenderText, dueText, countedText, adjustment;
        Button undo, clear;
        Action onExactPaid;
        int changeDue, counted;
        Rect lastSafe;
        Vector2Int lastSize;
        public bool IsOpen => overlay != null && overlay.gameObject.activeSelf;

        public static int TenderFor(int salePence)
        {
            if (salePence <= 0) throw new ArgumentOutOfRangeException(nameof(salePence));
            if (salePence <= 500) return 500;
            if (salePence <= 1000) return 1000;
            if (salePence <= 2000) return 2000;
            return (int)Math.Min(int.MaxValue, ((long)salePence + 999) / 1000 * 1000);
        }

        public void Open(int salePence, int tenderPence, Action paid)
        {
            if (IsOpen) return;
            if (salePence <= 0 || tenderPence < salePence) throw new ArgumentOutOfRangeException(nameof(tenderPence));
            if (paid == null) throw new ArgumentNullException(nameof(paid));
            if (overlay == null) Build();
            onExactPaid = paid;
            changeDue = tenderPence - salePence;
            totalText.text = MarketSession.Money(salePence);
            tenderText.text = MarketSession.Money(tenderPence);
            dueText.text = MarketSession.Money(changeDue);
            ResetHand();
            Fit();
            overlay.gameObject.SetActive(true);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
        }

        public void Close()
        {
            onExactPaid = null;
            if (overlay != null) overlay.gameObject.SetActive(false);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
        }

        void Pick(int slot)
        {
            if (!IsOpen || counted > int.MaxValue - Pence[slot]) return;
            counted += Pence[slot];
            picks.Push(slot);
            quantities[slot]++;
            DrawHand();
        }

        void UndoLast()
        {
            if (!IsOpen || picks.Count == 0) return;
            int slot = picks.Pop();
            counted -= Pence[slot];
            quantities[slot]--;
            DrawHand();
        }

        void ResetHand()
        {
            picks.Clear();
            Array.Clear(quantities, 0, quantities.Length);
            counted = 0;
            DrawHand();
        }

        void DrawHand()
        {
            countedText.text = MarketSession.Money(counted);
            for (int i = 0; i < Pence.Length; i++)
                quantitiesText[i].text = quantities[i] > 0 ? "×" + quantities[i] : "";
            undo.interactable = clear.interactable = picks.Count > 0;
            int balance = changeDue - counted;
            adjustment.color = balance < 0 ? Copper : balance > 0 ? Soft : Brass;
            adjustment.text = balance > 0 ? MarketSession.Money(balance) + " left to count"
                : balance < 0 ? MarketSession.Money(-balance) + " over · undo a pick" : "Exact change";
        }

        void HandOver()
        {
            if (!IsOpen) return;
            if (counted != changeDue)
            {
                adjustment.text = counted < changeDue ? "Add " + MarketSession.Money(changeDue - counted) + " more"
                    : "Take back " + MarketSession.Money(counted - changeDue);
                adjustment.color = Brass;
                return;
            }
            var paid = onExactPaid;
            Close();
            paid?.Invoke();
        }

        void Build()
        {
            plain = Resources.Load<Font>("ShopType/Barlow-Regular");
            if (!plain) plain = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            narrow = Resources.Load<Font>("ShopType/BarlowCondensed-SemiBold");
            if (!narrow) narrow = plain;

            overlay = new GameObject("Checkout cash drawer", typeof(RectTransform), typeof(Canvas),
                typeof(GraphicRaycaster), typeof(Image)).GetComponent<RectTransform>();
            overlay.SetParent(transform, false);
            var canvas = overlay.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 40;
            overlay.GetComponent<Image>().color = new Color32(9, 15, 13, 194);
            drawer = Plate(overlay, "Register", 0, 0, Width, Height, Case);
            drawer.anchorMin = drawer.anchorMax = drawer.pivot = new Vector2(.5f, .5f);

            Label(drawer, "Drawer title", "Cash drawer", 22, 6, 350, 49, 35, Paper, narrow);
            ActionKey("Back to till", 601, 8, 140, 43, Well, Paper, Close);
            Plate(drawer, "Receipt display", 18, 61, 724, 78, Paper);
            totalText = DisplayCell("Sale total", 30, false);
            tenderText = DisplayCell("Cash received", 260, false);
            dueText = DisplayCell("Change due", 500, true);
            Plate(drawer, "Display divider", 245, 72, 1, 54, Soft);
            Plate(drawer, "Display divider", 485, 72, 1, 54, Soft);
            for (int i = 0; i < Pence.Length; i++) BuildCompartment(i);

            Plate(drawer, "Tray edge", 18, 315, 724, 2, Well);
            Label(drawer, "Count caption", "In your hand", 22, 321, 170, 22, 17, Soft, plain);
            countedText = Label(drawer, "Counted change", "", 22, 339, 170, 46, 33, Paper, narrow);
            adjustment = Label(drawer, "Amount remaining", "", 22, 384, 287, 32, 19, Soft, plain);
            undo = ActionKey("Undo", 305, 348, 84, 61, Well, Paper, UndoLast);
            clear = ActionKey("Clear", 396, 348, 84, 61, Well, Paper, ResetHand);
            ActionKey("Give change", 491, 348, 251, 61, Brass, Ink, HandOver);
        }

        Text DisplayCell(string caption, float x, bool feature)
        {
            Label(drawer, caption, caption, x, 68, 204, 24, 17, Ink, plain);
            return Label(drawer, caption + " amount", "", x, 87, 209, 47, feature ? 35 : 29, Ink, narrow);
        }

        void BuildCompartment(int slot)
        {
            float x = 18 + (slot % 5) * 146, y = 150 + (slot / 5) * 81;
            int value = Pence[slot];
            string face = value >= 100 ? "£" + value / 100 : value + "p";
            var bin = Plate(drawer, face + " compartment", x, y, 140, 74, Well);
            Click(bin, () => Pick(slot));
            bool note = value >= 500;
            Color metal = value <= 2 ? Copper : value == 100 || value == 200 ? Brass : Silver;
            if (note)
            {
                var slip = Plate(bin, "Banknote", 17, 19, 104, 37,
                    value == 1000 ? new Color32(215, 174, 139, 255) : new Color32(160, 194, 178, 255));
                Plate(slip, "Note band", 10, 0, 5, 37, value == 1000 ? Copper : Soft);
            }
            else
            {
                var coin = Place(bin, "Coin", 44, 11, 52, 52);
                var faceImage = coin.gameObject.AddComponent<TillCoinFace>();
                faceImage.raycastTarget = false;
                faceImage.Configure(value, metal);
            }
            Label(bin, "Value", face, 15, 9, 110, 56, 24, Ink, narrow, TextAnchor.MiddleCenter);
            quantitiesText[slot] = Label(bin, "Picked", "", 96, 0, 39, 20, 15,
                Paper, narrow, TextAnchor.UpperRight);
        }

        Button ActionKey(string caption, float x, float y, float w, float h, Color fill, Color ink, Action invoke)
        {
            var button = Plate(drawer, caption, x, y, w, h, fill);
            Label(button, caption + " label", caption, 2, 0, w - 4, h, 23, ink, narrow, TextAnchor.MiddleCenter);
            return Click(button, invoke);
        }

        static Button Click(RectTransform rect, Action invoke)
        {
            var image = rect.GetComponent<Image>();
            image.raycastTarget = true;
            var key = rect.gameObject.AddComponent<Button>();
            key.targetGraphic = image;
            var colors = key.colors;
            colors.pressedColor = new Color(.68f, .68f, .63f, 1);
            colors.disabledColor = new Color(.75f, .75f, .75f, .46f);
            colors.fadeDuration = .06f;
            key.colors = colors;
            key.onClick.AddListener(() => invoke());
            return key;
        }

        static RectTransform Place(Transform parent, string name, float x, float y, float width, float height)
        {
            var rect = new GameObject(name, typeof(RectTransform)).GetComponent<RectTransform>();
            rect.SetParent(parent, false);
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
            rect.anchoredPosition = new Vector2(x, -y);
            rect.sizeDelta = new Vector2(width, height);
            return rect;
        }

        static RectTransform Plate(Transform parent, string name, float x, float y, float w, float h, Color fill)
        {
            var rect = Place(parent, name, x, y, w, h);
            var image = rect.gameObject.AddComponent<Image>();
            image.color = fill;
            image.raycastTarget = false;
            return rect;
        }

        static Text Label(Transform parent, string name, string value, float x, float y, float w, float h,
            int size, Color ink, Font font, TextAnchor alignment = TextAnchor.MiddleLeft)
        {
            var label = Place(parent, name, x, y, w, h).gameObject.AddComponent<Text>();
            label.font = font;
            label.fontSize = size;
            label.alignment = alignment;
            label.color = ink;
            label.text = value;
            label.raycastTarget = false;
            label.supportRichText = false;
            return label;
        }

        void LateUpdate()
        {
            if (IsOpen && (Screen.safeArea != lastSafe || Screen.width != lastSize.x || Screen.height != lastSize.y))
                Fit();
        }

        void Fit()
        {
            lastSize = new Vector2Int(Screen.width, Screen.height);
            lastSafe = Screen.safeArea;
            var area = lastSafe;
            if (area.width <= 0 || area.height <= 0) area = new Rect(0, 0, lastSize.x, lastSize.y);
            float scale = Mathf.Max(.01f, Mathf.Min((area.width - 16f) / Width, (area.height - 16f) / Height));
            drawer.localScale = Vector3.one * scale;
            drawer.anchoredPosition = area.center - new Vector2(lastSize.x, lastSize.y) * .5f;
        }

        void OnDisable()
        {
            if (IsOpen) Close();
        }

        void OnDestroy()
        {
            onExactPaid = null;
            if (overlay != null) Destroy(overlay.gameObject);
        }
    }

    // Coin outlines share the default UI material and need no generated textures.
    sealed class TillCoinFace : MaskableGraphic
    {
        int pence;
        public void Configure(int denomination, Color metal)
        {
            pence = denomination;
            color = metal;
            SetVerticesDirty();
        }

        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            Rect box = GetPixelAdjustedRect();
            float r = Mathf.Min(box.width, box.height) * .5f;
            int sides = pence == 50 || pence == 20 ? 7 : pence == 100 ? 12 : 36;
            Disk(mesh, box.center, r, sides, Color.Lerp(color, Color.black, .42f));
            Disk(mesh, box.center, r * .95f, sides, color);
            Disk(mesh, box.center, r * .81f, sides, Color.Lerp(color, Color.black, .21f));
            Color center = pence == 200 ? new Color32(201, 204, 185, 255) : color;
            Disk(mesh, box.center, r * .78f, sides, center);
        }

        static void Disk(VertexHelper mesh, Vector2 origin, float radius, int sides, Color fill)
        {
            int start = mesh.currentVertCount;
            mesh.AddVert(origin, fill, Vector2.zero);
            for (int i = 0; i < sides; i++)
            {
                float angle = Mathf.PI * .5f + i * (Mathf.PI * 2f / sides);
                mesh.AddVert(origin + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius, fill, Vector2.zero);
            }
            for (int i = 0; i < sides; i++) mesh.AddTriangle(start, start + i + 1, start + (i + 1) % sides + 1);
        }
    }
}
