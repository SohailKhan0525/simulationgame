using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Qofeno
{
    /// A street-level fish-quay shop. Positions are in metres, with the entrance to the south.
    public sealed partial class HarborBlock : MonoBehaviour
    {
        public static readonly Vector3 Spawn = new Vector3(0f, 0f, -1.45f);
        public static readonly Vector3 ShelfPosition = new Vector3(-2.30f, 0f, 2.50f);
        public static readonly Vector3 CheckoutPosition = new Vector3(1.80f, 0f, 1.75f);
        public static readonly Vector3 DeliveryPosition = new Vector3(-3.40f, 0f, -0.25f);
        public static readonly Vector3 DeskPosition = new Vector3(3.15f, 0f, -0.95f);
        public static readonly Vector3 CustomerPosition = new Vector3(2.00f, 0f, 2.88f);

        const float StreetEnd = 62f;
        const float FloorY = -0.08f;
        readonly Dictionary<Material, Batch> batches = new Dictionary<Material, Batch>();
        readonly List<Object> owned = new List<Object>();
        readonly List<Light> shopLights = new List<Light>();
        readonly List<TrafficCar> traffic = new List<TrafficCar>();
        Material tile, brick, pavement, asphalt, plaster, milk, ink, marine, brass, wood;
        Material slate, charcoal, window, lamp, line, ochre, scarlet, neon, sky;
        Font signFont;
        Material signMaterial;
        Light sun;
        Transform hourHand, minuteHand;
        readonly List<TextMesh> tradingSigns = new List<TextMesh>(2);
        float lastLightingHour = float.NaN;
        readonly Color morning = new Color(1f, .73f, .49f);
        readonly Color noon = new Color(1f, .94f, .81f);

        sealed class TrafficCar
        {
            public Rigidbody body;
            public float speed;
        }

        // One mesh per finish. Meter-based face UVs let the same photograph span a wall or a curb.
        sealed class Batch
        {
            public readonly List<Vector3> vertices = new List<Vector3>();
            public readonly List<Vector3> normals = new List<Vector3>();
            public readonly List<Vector2> uv = new List<Vector2>();
            public readonly List<int> indices = new List<int>();

            public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d)
            {
                Vector3 normal = Vector3.Cross(b - a, d - a).normalized;
                int first = vertices.Count;
                Add(a, normal); Add(b, normal); Add(c, normal); Add(d, normal);
                indices.Add(first); indices.Add(first + 1); indices.Add(first + 2);
                indices.Add(first); indices.Add(first + 2); indices.Add(first + 3);
            }

            public void Print(Vector3 center, Vector3 right, float height, Rect region)
            {
                int first = vertices.Count;
                Vector3 up = Vector3.up * height * .5f;
                Vector3 halfRight = right * .5f;
                Quad(center-halfRight-up, center-halfRight+up, center+halfRight+up, center+halfRight-up);
                uv[first] = new Vector2(region.xMin,region.yMin);
                uv[first+1] = new Vector2(region.xMin,region.yMax);
                uv[first+2] = new Vector2(region.xMax,region.yMax);
                uv[first+3] = new Vector2(region.xMax,region.yMin);
            }

            void Add(Vector3 v, Vector3 n)
            {
                vertices.Add(v);
                normals.Add(n);
                if (Mathf.Abs(n.y) > .70f) uv.Add(new Vector2(v.x, v.z));
                else if (Mathf.Abs(n.x) > .70f) uv.Add(new Vector2(v.z, v.y));
                else uv.Add(new Vector2(v.x, v.y));
            }
        }

        public void Build(float hour)
        {
            Palette();
            ShopShell();
            TradingSign();
            ShopDetails();
            UtilityDoor();
            WallClock();
            OfficeDesk();
            DressMarket();
            Street();
            Waterfront();
            QuayStop();
            BakeGeometry();
            BuildLighting();
            AddTraffic(-29f, -8.1f, 5.0f);
            AddTraffic(18f, -11.1f, -5.7f);
            SetHour(hour);
        }

        void Palette()
        {
            tile = Finish("Honed shop tile", "E6DED1", .20f, "floor_tiles_06", .34f);
            brick = Finish("Waterfront brick", "E5CEB9", .10f, "red_brick_03", .56f);
            pavement = Finish("Pier concrete", "DBD3BF", .10f, "concrete_pavement", .48f);
            asphalt = Finish("Worn road", "A69F9C", .09f, "asphalt_04", .25f);
            plaster = Finish("Glazed ivory plaster", "D6C8AB", .16f, "limewash", .67f);
            milk = Finish("Milk white enamel", "EBE5CC", .26f);
            ink = Finish("Blue black iron", "273431", .33f);
            marine = Finish("Petrol green enamel", "355F57", .31f);
            brass = Finish("Brushed brass", "AE8654", .34f);
            wood = Finish("Varnished oak", "A9794F", .24f, "timber", 1.15f);
            slate = Finish("Slate trim", "687675", .22f);
            charcoal = Finish("Charcoal rubber", "363B39", .12f);
            window = Finish("Window reflection", "769090", .68f);
            lamp = Finish("Porcelain luminous tube", "FFF3D6", .30f);
            lamp.EnableKeyword("_EMISSION");
            lamp.SetColor("_EmissionColor", new Color(1f, .87f, .66f) * .85f);
            neon = Finish("Terminal phosphor", "A6D0BC", .30f);
            neon.EnableKeyword("_EMISSION");
            neon.SetColor("_EmissionColor", new Color(.19f, .42f, .32f));
            line = Finish("Worn road paint", "D4CFB5", .12f);
            ochre = Finish("Ferry ochre", "AD8156", .17f);
            scarlet = Finish("Oxide red", "9A564A", .18f);
            signFont = Resources.Load<Font>("ShopType/BarlowCondensed-SemiBold");
            if (signFont == null) signFont = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            var signShader = Resources.Load<Shader>("MarketWorldText");
            if (signShader != null && signShader.isSupported)
            {
                signMaterial = new Material(signShader) { name = "Harbor sign lettering" };
                owned.Add(signMaterial);
                RefreshSignAtlas(signFont);
                Font.textureRebuilt += RefreshSignAtlas;
            }
            else
            {
                signMaterial = signFont.material;
                Debug.LogWarning("World text shader unavailable. Using the default font material.");
            }
        }

        void RefreshSignAtlas(Font font)
        {
            if (font == signFont) signMaterial.mainTexture = font.material.mainTexture;
        }

        internal void ApplyWorldFont(TextMesh label)
        {
            label.font = signFont;
            var renderer = label.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = signMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
        }

        static Color Hex(string value)
        {
            Color color;
            ColorUtility.TryParseHtmlString("#" + value, out color);
            return color;
        }

        Material Finish(string label, string color, float smooth, string texture = null, float repeat = 1f)
        {
            var mat = ShopModels.CreateSurfaceMaterial(label);
            mat.color = Hex(color);
            mat.SetFloat("_Glossiness", smooth);
            if (texture != null)
            {
                mat.mainTexture = Resources.Load<Texture2D>("HarborMaterials/" + texture);
                mat.mainTextureScale = Vector2.one * repeat;
            }
            owned.Add(mat);
            return mat;
        }

        Batch GetBatch(Material material)
        {
            Batch batch;
            if (!batches.TryGetValue(material, out batch))
            {
                batch = new Batch();
                batches.Add(material, batch);
            }
            return batch;
        }

        void Box(Material m, float x, float y, float z, float w, float h, float depth)
        {
            Vector3 center = new Vector3(x, y, z);
            float dx = w * .5f, dy = h * .5f, dz = depth * .5f;
            Vector3 a = center + new Vector3(-dx, -dy, -dz);
            Vector3 b = center + new Vector3(-dx, dy, -dz);
            Vector3 c = center + new Vector3(dx, dy, -dz);
            Vector3 d = center + new Vector3(dx, -dy, -dz);
            Vector3 e = center + new Vector3(-dx, -dy, dz);
            Vector3 f = center + new Vector3(-dx, dy, dz);
            Vector3 g = center + new Vector3(dx, dy, dz);
            Vector3 i = center + new Vector3(dx, -dy, dz);
            Batch batch = GetBatch(m);
            batch.Quad(a, b, c, d); batch.Quad(i, g, f, e);
            batch.Quad(e, f, b, a); batch.Quad(d, c, g, i);
            batch.Quad(b, f, g, c); batch.Quad(e, a, d, i);
        }

        void Solid(string label, Material m, float x, float y, float z, float w, float h, float d)
        {
            Box(m, x,y,z,w,h,d);
            Obstacle(label, new Vector3(x, y, z), new Vector3(w, h, d));
        }

        void Obstacle(string label, Vector3 center, Vector3 size)
        {
            var node = new GameObject(label);
            node.transform.SetParent(transform, false);
            node.transform.localPosition = center;
            node.AddComponent<BoxCollider>().size = size;
        }

        // Front is open at the door and optically open at the large display windows.
        void ShopShell()
        {
            Solid("Shop slab", tile, 0, FloorY, .85f, 9.9f, .16f, 7.9f);
            Solid("West masonry", plaster, -4.95f, 1.79f, .85f, .18f, 3.58f, 7.9f);
            Solid("East masonry", plaster, 4.95f, 1.79f, .85f, .18f, 3.58f, 7.9f);
            Solid("Rear masonry", plaster, 0, 1.79f, 4.80f, 10f, 3.58f, .18f);
            Solid("Shop roof", milk, 0, 3.61f, .85f, 10.2f, .18f, 8.15f);
            for (int side = -1; side <= 1; side += 2)
            {
                float x = side * 4.84f;
                Box(marine, x, .40f, .82f, .055f, .80f, 7.75f);
                Box(brass, x, .82f, .82f, .07f, .032f, 7.75f);
                Box(ink, x, .07f, .82f, .085f, .14f, 7.75f);
                Box(wood, x-side*.045f, .65f, .83f, .089f, .068f, 7.70f);
                float wx = side * 3.13f;
                Box(marine, wx, .28f, -3.03f, 3.68f, .56f, .15f);
                // Glass is clear enough to see traffic; mullions and a sill describe the plane.
                Obstacle("Shop window", new Vector3(wx, 1.42f, -3.03f), new Vector3(3.72f, 2.84f, .12f));
                Box(wood, wx, .59f, -3.03f, 3.8f, .065f, .28f);
                foreach (float offset in new [] { -1.84f, 0f, 1.84f })
                    Box(marine, wx + offset, 1.65f, -3.04f, .085f, 2.27f, .15f);
                Box(marine, wx, 2.38f, -3.04f, 3.72f, .075f, .15f);
                Box(marine, wx, 2.74f, -3.04f, 3.72f, .10f, .15f);
                Box(marine, side * 1.27f, 1.36f, -3.06f, .13f, 2.72f, .21f);
            }
            Box(wood, 0, 2.66f, -3.04f, 2.6f, .13f, .18f);
            Box(ink, 0, .008f, -2.66f, 2.05f, .018f, .80f);
            for (int i = 0; i < 14; i++)
                Box(slate, 0, .02f, -3.00f + i * .053f, 1.97f, .008f, .013f);

            Box(marine, 0, 3.10f, -3.12f, 10.14f, .66f, .25f);
            Box(brass, 0, 2.81f, -3.25f, 10.12f, .027f, .035f);
            Box(brass, 0, 3.39f, -3.25f, 10.12f, .027f, .035f);
            Legend("HARBOR  MARKET", new Vector3(0, 3.10f, -3.26f), 0, .29f, Hex("F3E6C8"), true);
            Legend("G R O C E R S", new Vector3(-3.60f, 3.10f, -3.26f), 0, .11f, Hex("E4D4B6"));
            Legend("E S T .   1 9 6 4", new Vector3(3.60f, 3.10f, -3.26f), 0, .11f, Hex("E4D4B6"));
            Awning(-3.10f); Awning(3.10f);
        }


        void TradingSign()
        {
            const float x=1.83f, y=1.75f, z=-3.04f;
            Box(ink,x,y,z,.61f,.33f,.055f);
            for(int side=-1;side<=1;side+=2)
            {
                Box(brass,x+side*.215f,2.14f,z,.012f,.46f,.012f);
                float surface=z+side*.034f, yaw=side<0 ? 0f : 180f;
                Legend("OPEN",new Vector3(x,y+.039f,surface),yaw,.112f,Hex("F1E5BE"),true,true);
                Legend("08:00 – 21:00",new Vector3(x,y-.080f,surface),yaw,.058f,Hex("D8C6A1"));
            }
        }

        void Awning(float x)
        {
            // Sloped sheet, stitched seams, and a weighted front valance.
            float x0=x-1.84f, x1=x+1.84f;
            var a = new Vector3(x0, 2.79f, -3.21f);
            var b = new Vector3(x0, 2.49f, -4.02f);
            var c = new Vector3(x1, 2.49f, -4.02f);
            var d = new Vector3(x1, 2.79f, -3.21f);
            GetBatch(marine).Quad(a, d, c, b);
            GetBatch(marine).Quad(b, c, d, a);
            Box(marine, x, 2.43f, -4.02f, 3.68f, .12f, .035f);
            Box(milk, x, 2.40f, -4.041f, 3.68f, .012f, .008f);
            for (int i = 0; i <= 4; i++)
            {
                float u = Mathf.Lerp(x0+.02f, x1-.02f, i/4f);
                Vector3 start = new Vector3(u, 2.793f, -3.21f);
                Vector3 end = new Vector3(u, 2.493f, -4.02f);
                Vector3 seam = Vector3.right * .012f;
                GetBatch(brass).Quad(start, start+seam, end+seam, end);
            }
        }

        void ShopDetails()
        {
            Box(marine, 0, .42f, 4.67f, 9.76f, .84f, .08f);
            Box(brass, 0, .86f, 4.63f, 9.75f, .034f, .06f);
            Box(ink, 0, .08f, 4.59f, 9.7f, .16f, .13f);
            for (int i=0; i<19; i++) Box(wood, -4.40f+i*.24f, 1.64f, 4.62f, .025f, 1.47f, .025f);
            Box(marine, -2.30f, 2.42f, 4.55f, 4.42f, .42f, .13f);
            Legend("P A N T R Y", new Vector3(-2.30f,2.42f,4.47f), 0,.225f,Hex("EFE5CB"),true);
            Box(ink, 1.80f, 2.43f, 4.62f, 2.38f, .43f, .08f);
            Legend("PAY  HERE", new Vector3(1.80f,2.43f,4.565f), 0,.205f,Hex("EFE5CB"),true);
            for (int i=0; i<4; i++)
            {
                float x=-3.57f+i*2.38f;
                Box(wood,x,3.40f,.80f,.11f,.21f,7.78f);
                Box(ink,x,3.30f,.8f,.12f,.018f,7.78f);
            }
            for (int i=0; i<3; i++)
            {
                float x=(i-1)*3.04f;
                Box(charcoal,x,3.45f,.55f,.055f,.08f,4.50f);
                for (int j=0; j<2; j++)
                {
                    float z=j==0 ? -.91f : 2.18f;
                    Box(ink,x,3.30f,z,.25f,.12f,1.56f);
                    Box(milk,x,3.22f,z,.26f,.045f,1.56f);
                    Box(lamp,x,3.19f,z,.185f,.035f,1.45f);
                }
            }
            Box(milk,3.60f,2.72f,4.62f,1.42f,.48f,.10f);
            for(int i=0; i<6; i++) Box(slate,3.60f,2.55f+.065f*i,4.56f,1.27f,.019f,.04f);
            // A dispatch clipboard and shallow cubbies sit beside the cartons on the west wall.
            Box(wood,-4.79f,1.12f,-.26f,.065f,.49f,.34f);
            Box(milk,-4.747f,1.12f,-.26f,.018f,.405f,.278f);
            Box(ink,-4.729f,1.31f,-.26f,.02f,.054f,.13f);
            for(int i=0;i<4;i++) Box(slate,-4.734f,1.22f-i*.060f,-.27f,.010f,.013f,.179f);
            // Delivery landing: edge stripes, oak slats and paired cross-bearers under the carton.
            Box(ink,DeliveryPosition.x,.010f,DeliveryPosition.z,1.02f,.020f,2.15f);
            for(int i=0;i<7;i++)
                Box(wood,DeliveryPosition.x-.42f+i*.14f,.023f,DeliveryPosition.z,.12f,.022f,2.08f);
            for(int end=-1;end<=1;end+=2)
            {
                Box(ochre,DeliveryPosition.x+end*.55f,.007f,DeliveryPosition.z,.04f,.012f,2.28f);
                Box(ochre,DeliveryPosition.x,.007f,DeliveryPosition.z+end*1.12f,1.14f,.012f,.04f);
            }
            for(int bay=-1;bay<=1;bay++)
                Box(brass,DeliveryPosition.x+.28f,.036f,DeliveryPosition.z+bay*.66f,.19f,.006f,.025f);
            // Keep the raised landing shallow so that a boxed delivery sits at its navigation marker.
            Legend("RECEIVING", new Vector3(-4.81f,1.52f,-.26f),-90,.195f,Hex("213F37"),true);
        }


        void UtilityDoor()
        {
            const float x = -4.12f;
            Box(ink,x,1.10f,4.50f,1.23f,2.20f,.15f);
            Box(marine,x,1.061f,4.398f,1.07f,2.11f,.066f);
            Box(slate,x,1.51f,4.355f,.59f,.56f,.022f);
            Box(window,x,1.51f,4.336f,.51f,.47f,.019f);
            for (int row=-1;row<=1;row++)
                Box(ink,x,1.51f+row*.13f,4.324f,.50f,.011f,.008f);
            Box(slate,x,.18f,4.353f,.93f,.28f,.020f);
            Box(brass,x+.383f,.99f,4.322f,.046f,.15f,.048f);
            Box(ink,x+.336f,1.012f,4.283f,.131f,.034f,.065f);
            Legend("UTILITIES",new Vector3(x,1.15f,4.345f),0,.060f,Hex("E9DFC6"));
            // Extinguisher beside the staff door. Layered sections avoid a silhouette made of cubes.
            float fx=-3.44f;
            Barrel(scarlet,new Vector3(fx,.85f,4.48f),.087f,.40f,12);
            Barrel(scarlet,new Vector3(fx,1.064f,4.48f),.063f,.042f,12);
            Barrel(brass,new Vector3(fx,1.107f,4.48f),.028f,.05f,10);
            Box(ink,fx+.028f,1.153f,4.47f,.14f,.033f,.056f);
            Box(ink,fx+.092f,.97f,4.48f,.026f,.33f,.025f);
            Box(milk,fx,.872f,4.391f,.104f,.14f,.012f);
            Box(scarlet,fx,.885f,4.382f,.065f,.028f,.008f);
        }

        void Barrel(Material material, Vector3 c, float radius, float height, int sides)
        {
            Batch mesh=GetBatch(material);
            Vector3 up=Vector3.up*height*.5f;
            for(int i=0;i<sides;i++)
            {
                float a=i*Mathf.PI*2f/sides, b=(i+1)*Mathf.PI*2f/sides;
                Vector3 sa=radius*new Vector3(Mathf.Cos(a),0,Mathf.Sin(a));
                Vector3 sb=radius*new Vector3(Mathf.Cos(b),0,Mathf.Sin(b));
                mesh.Quad(c+sa-up,c+sa+up,c+sb+up,c+sb-up);
                // A tiny concentric top cap leaves room for the cylinder's neck.
                mesh.Quad(c+sa+up,c+sa*.18f+up,c+sb*.18f+up,c+sb+up);
            }
        }

        void WallClock()
        {
            Vector3 c=new Vector3(.249f,2.405f,4.562f);
            Batch face=GetBatch(milk), rim=GetBatch(ink);
            const int divisions=36;
            for(int i=0;i<divisions;i++)
            {
                float a=i*Mathf.PI*2f/divisions,b=(i+1)*Mathf.PI*2f/divisions;
                Vector3 va=new Vector3(Mathf.Sin(a),Mathf.Cos(a),0);
                Vector3 vb=new Vector3(Mathf.Sin(b),Mathf.Cos(b),0);
                rim.Quad(c+.211f*va,c+.211f*vb,c+.187f*vb,c+.187f*va);
                face.Quad(c+.187f*va,c+.187f*vb,c+.006f*vb,c+.006f*va);
                if (i%3==0)
                {
                    Vector3 mark=c+.161f*va;
                    Box(ink,mark.x,mark.y,c.z-.006f,.012f,.012f,.008f);
                }
            }
            hourHand=ClockHand(c+Vector3.back*.014f,.097f,.013f);
            minuteHand=ClockHand(c+Vector3.back*.021f,.147f,.008f);
        }

        Transform ClockHand(Vector3 center, float length, float width)
        {
            var pivot=new GameObject("Clock hand");
            pivot.transform.SetParent(transform,false);
            pivot.transform.localPosition=center;
            var needle=GameObject.CreatePrimitive(PrimitiveType.Cube);
            needle.transform.SetParent(pivot.transform,false);
            needle.transform.localPosition=Vector3.up*(length*.44f);
            needle.transform.localScale=new Vector3(width,length,.006f);
            needle.GetComponent<Renderer>().sharedMaterial=ink;
            var collider=needle.GetComponent<Collider>();
            collider.enabled=false;
            Destroy(collider);
            return pivot.transform;
        }

        void OfficeDesk()
        {
            Vector3 p = DeskPosition;
            Solid("Office workstation",wood,p.x,.82f,p.z,.92f,.095f,1.55f);
            for(int i=-1;i<=1;i+=2)
            {
                Box(marine,p.x+.02f,.41f,p.z+i*.67f,.73f,.78f,.058f);
                Box(ink,p.x+.02f,.035f,p.z+i*.67f,.78f,.065f,.10f);
            }
            Box(marine,p.x+.38f,.54f,p.z,.045f,.51f,1.30f);
            Box(ink,p.x+.19f,.905f,p.z,.20f,.055f,.32f);
            Box(slate,p.x+.24f,1.066f,p.z,.06f,.35f,.085f);
            Box(ink,p.x+.21f,1.30f,p.z,.075f,.53f,.89f);
            Box(neon,p.x+.169f,1.30f,p.z,.012f,.46f,.82f);
            Box(marine,p.x+.157f,1.476f,p.z,.008f,.099f,.78f);
            Legend("HARBOR  SUPPLY",new Vector3(p.x+.151f,1.476f,p.z),90,.054f,Color.white,true);
            for(int row=0;row<3;row++)
            {
                Box(marine,p.x+.154f,1.368f-row*.074f,p.z+.12f,.012f,.015f,.42f);
                Box(slate,p.x+.154f,1.368f-row*.074f,p.z-.26f,.012f,.028f,.10f);
            }
            Box(charcoal,p.x-.16f,.891f,p.z+.06f,.25f,.035f,.67f);
            for(int row=0;row<4;row++)
                for(int key=0;key<12;key++)
                    Box(slate,p.x-.25f+row*.052f,.913f,p.z-.215f+key*.048f,.036f,.011f,.036f);
            Box(ink,p.x-.17f,.90f,p.z-.39f,.14f,.047f,.087f);
            Legend("SHOP  OFFICE", new Vector3(4.84f,1.91f,p.z),90,.19f,Hex("29453C"),true);
        }

        void Street()
        {
            Solid("Road and dock ground", asphalt, 0,-.265f,-10.32f,133f,.29f,15f);
            Solid("Market footway", pavement, 0,-.09f,-4.59f,133f,.17f,3.13f);
            Solid("Dock footway", pavement, 0,-.09f,-15.63f,133f,.17f,4.08f);
            Box(milk,0,-.07f,-6.14f,133f,.13f,.16f);
            Box(milk,0,-.07f,-13.57f,133f,.13f,.16f);
            for(int i=-8;i<=8;i++)
            {
                Box(line,i*7.5f,-.113f,-9.85f,2.80f,.012f,.085f);
                Box(slate,i*7.5f+.5f,-.001f,-5.93f,.47f,.012f,.22f);
                for(int j=0;j<5;j++) Box(ink,i*7.5f+.32f+j*.084f,.008f,-5.93f,.027f,.008f,.175f);
            }
            for (int i=0; i<7; i++)
                Box(line,8.35f, -.110f, -6.83f-i*.94f,1.98f,.015f,.40f);
            for(int side=-1;side<=1;side+=2)
            {
                for(int i=0;i<4;i++)
                {
                    float x=side*(10.04f+i*9.96f);
                    StreetFacade(x,-2.91f,i%2==0 ? brick : plaster,i%2==0 ? slate : scarlet,false);
                }
            }
            StreetFacade(-18.5f,-17.60f,brick,marine,true);
            StreetFacade(-8.6f,-17.60f,plaster,slate,true);
            StreetFacade(12.7f,-17.60f,brick,scarlet,true);
            StreetFacade(22.63f,-17.60f,plaster,ochre,true);
            for(int i=-3;i<=3;i++)
            {
                float x=i*11.9f + 5.85f;
                Box(ink,x,1.98f,-14.24f,.135f,3.94f,.135f);
                Box(ink,x,3.88f,-13.83f,.16f,.13f,.90f);
                Box(slate,x,3.81f,-13.42f,.34f,.16f,.49f);
                Box(lamp,x,3.72f,-13.42f,.28f,.032f,.41f);
                Box(slate,x,.12f,-14.24f,.30f,.24f,.30f);
            }
            // Street limits coincide with fencing and the continuous neighboring facades.
            for(int side=-1;side<=1;side+=2)
            {
                float x=side*26.6f;
                foreach(float walk in new [] {-4.58f,-15.48f})
                {
                    Solid("Pedestrian service gate",ink,x,.56f,walk,.10f,1.12f,3.02f);
                    Box(ochre,x,.95f,walk,.12f,.08f,3.06f);
                }
                // The carriageway remains open under the rail viaduct. Cars recycle behind its piers.
                float mouth=side*47f;
                Box(brick,mouth,3.47f,-9.83f,26f,1.12f,10.1f);
                Box(ink,mouth,4.12f,-9.83f,26f,.20f,10.2f);
                for(int n=0;n<5;n++)
                {
                    float column=mouth+side*(n-2)*5.9f;
                    Box(brick,column,1.42f,-5.91f,.88f,2.92f,.60f);
                    Box(brick,column,1.42f,-13.80f,.88f,2.92f,.60f);
                }
                Obstacle("Facade return",new Vector3(side*14.97f,1.7f,-2.72f),new Vector3(19.93f,3.4f,.22f));
            }
        }

        void StreetFacade(float x, float z, Material wall, Material trim, bool facesNorth)
        {
            float face=facesNorth ? 1f : -1f;
            float inside=z-face*2.5f;
            Solid("Warehouse masonry",wall,x,2.53f,inside,9.88f,5.06f,5.0f);
            Box(ink,x,5.07f,inside,9.99f,.19f,5.20f);
            Box(trim,x,3.17f,z+.09f*face,9.83f,.27f,.22f);
            for(int w=-1;w<=1;w++)
            {
                float wx=x+w*2.88f;
                Box(trim,wx,4.11f,z+.065f*face,1.50f,1.38f,.12f);
                Box(window,wx,4.11f,z+.133f*face,1.30f,1.20f,.027f);
                Box(ink,wx,4.08f,z+.156f*face,1.32f,.045f,.026f);
                Box(ink,wx,4.10f,z+.157f*face,.042f,1.21f,.026f);
                Box(plaster,wx,3.40f,z+.08f*face,1.62f,.105f,.22f);
            }
            for(int w=-1;w<=1;w+=2)
            {
                float wx=x+w*2.76f;
                Box(trim,wx,1.43f,z+.06f*face,2.76f,2.50f,.14f);
                Box(window,wx,1.62f,z+.15f*face,2.52f,1.85f,.07f);
                Box(trim,wx,1.58f,z+.195f*face,.08f,1.99f,.05f);
                Box(trim,wx,2.11f,z+.195f*face,2.59f,.065f,.05f);
            }
            Box(trim,x,1.19f,z+.09f*face,1.20f,2.38f,.15f);
            Box(window,x,1.72f,z+.184f*face,.86f,.95f,.06f);
            Box(brass,x+.39f,.99f,z+.232f*face,.12f,.055f,.056f);
            Box(ink,x,2.78f,z+.12f*face,4.72f,.41f,.125f);
            if(Mathf.Abs(x)<23f)
            {
                string sign = facesNorth
                    ? (x<0 ? (x < -12 ? "QUAY  FRUIT" : "FERRY  STORES") : (x>18 ? "NET  &  TWINE" : "FISH  AUCTION"))
                    : (x<0 ? (x < -15 ? "STEAM  LAUNDRY" : "PIER  WORKS") : (x>15 ? "FERRY  POST" : "TIDE  BAKERY"));
                Legend(sign,new Vector3(x,2.78f,z+.196f*face),facesNorth ? 180 : 0,.165f,Hex("F1DDBA"),true);
            }
        }

        void Waterfront()
        {
            // Sight line through the break in the warehouses ends on a quay and a moored ferry.
            Solid("Quay edge",pavement,0,-.11f,-18.18f,133f,.21f,1.06f);
            for(int i=-8;i<=8;i++)
            {
                float x=i*3.32f;
                Box(ink,x,.54f,-18.61f,.08f,1.08f,.08f);
            }
            Solid("Waterfront guardrail",marine,0,1.02f,-18.61f,54f,.10f,.11f);
            Box(ink,0,.52f,-18.61f,54f,.055f,.06f);
            Box(window,0,-.82f,-31f,135f,.15f,27f);
            Box(ink,4.60f,-.04f,-26.7f,10.8f,.94f,2.59f);
            Box(milk,4.60f,.46f,-26.7f,10.2f,.26f,2.45f);
            Box(ochre,4.53f,.92f,-26.7f,6.75f,.69f,1.97f);
            for (int i=0;i<9;i++)
                Box(ink,1.77f+i*.68f,1.03f,-25.69f,.49f,.37f,.045f);
            Box(milk,4.52f,1.33f,-26.7f,7.19f,.13f,2.16f);
            Box(marine,3.27f,1.65f,-26.7f,1.87f,.57f,1.81f);
            Box(window,3.27f,1.70f,-25.77f,1.62f,.29f,.04f);
            Box(ink,3.27f,1.97f,-26.7f,2.08f,.13f,1.99f);
            Box(scarlet,5.89f,1.77f,-26.7f,.54f,.89f,.55f);
            Box(ink,5.89f,2.22f,-26.7f,.58f,.16f,.59f);
            for(int i=-2; i<=2; i++)
            {
                float x=i*17.0f;
                Box(slate,x,1.5f,-48f,15f,4.50f,6f);
                Box(ink,x,3.86f,-48f,15.6f,.24f,6.5f);
                Box(brass,x+6.5f,5.2f,-44f,.23f,10.4f,.23f);
                Box(brass,x+3.8f,10.2f,-44f,6.42f,.31f,.32f);
                Box(ink,x+1.0f,8.52f,-44f,.045f,3.4f,.045f);
            }
        }

        void Legend(string text, Vector3 position, float yaw, float height, Color color, bool bold=false, bool trading=false)
        {
            var node=new GameObject(text);
            node.transform.SetParent(transform,false);
            node.transform.localPosition=position;
            node.transform.localRotation=Quaternion.Euler(0,yaw,0);
            var label=node.AddComponent<TextMesh>();
            ApplyWorldFont(label);
            label.fontSize=80;
            // Font glyphs at characterSize 1 occupy about 0.7 units at the legacy 10px design size.
            // Set pixel-to-world scale explicitly so Unity's fontSize only affects atlas resolution.
            label.characterSize=height * 10f / 60f;
            label.anchor=TextAnchor.MiddleCenter;
            label.alignment=TextAlignment.Center;
            label.fontStyle=bold ? FontStyle.Bold : FontStyle.Normal;
            label.color=color;
            label.text=text;
            if(trading) tradingSigns.Add(label);
        }

        void BakeGeometry()
        {
            foreach(var entry in batches)
            {
                Batch src=entry.Value;
                var mesh=new Mesh {name=entry.Key.name+" geometry"};
                if(src.vertices.Count>65535) mesh.indexFormat=IndexFormat.UInt32;
                mesh.SetVertices(src.vertices);
                mesh.SetNormals(src.normals);
                mesh.SetUVs(0,src.uv);
                mesh.SetTriangles(src.indices,0);
                mesh.RecalculateBounds();
                mesh.UploadMeshData(true);
                owned.Add(mesh);
                var go=new GameObject(entry.Key.name);
                go.transform.SetParent(transform,false);
                go.AddComponent<MeshFilter>().sharedMesh=mesh;
                go.AddComponent<MeshRenderer>().sharedMaterial=entry.Key;
            }
            batches.Clear();
        }

        void BuildLighting()
        {
            var node=new GameObject("Quayside sun");
            node.transform.SetParent(transform,false);
            sun=node.AddComponent<Light>();
            sun.type=LightType.Directional;
            sun.shadows=LightShadows.Hard;
            sun.shadowBias=.035f;
            sun.shadowNormalBias=.25f;
            RenderSettings.sun=sun;
            RenderSettings.ambientMode=AmbientMode.Trilight;
            RenderSettings.fog=true;
            RenderSettings.fogMode=FogMode.ExponentialSquared;
            RenderSettings.fogDensity=.015f;
            var skyTemplate = Resources.Load<Material>("MarketSky");
            if (skyTemplate != null)
            {
                sky = new Material(skyTemplate) { name = "Tidal sky" };
                sky.SetFloat("_SunSize",.036f);
                sky.SetFloat("_AtmosphereThickness",.75f);
                sky.SetColor("_GroundColor",Hex("666B66"));
                owned.Add(sky);
                RenderSettings.skybox=sky;
            }
            AddFixture("Pantry strip",new Vector3(-2.62f,2.98f,1.65f),6.2f);
            AddFixture("Counter strip",new Vector3(2.12f,2.96f,1.65f),6.2f);
            AddFixture("Window strip",new Vector3(0f,2.96f,-1.70f),5.5f);
        }

        void AddFixture(string label,Vector3 position,float range)
        {
            var node=new GameObject(label);
            node.transform.SetParent(transform,false);
            node.transform.localPosition=position;
            var light=node.AddComponent<Light>();
            light.type=LightType.Point;
            light.color=new Color(1f,.92f,.81f);
            light.range=range;
            light.shadows=LightShadows.None;
            light.renderMode=LightRenderMode.Auto;
            shopLights.Add(light);
        }

        /// Accepts decimal local time. The sun, ambient light, fog, sky and shop fixtures change together.
        public void SetHour(float hour)
        {
            if(sun==null) return;
            hour=Mathf.Repeat(hour,24f);
            if (Mathf.Abs(hour-lastLightingHour)<.006f) return;
            lastLightingHour=hour;
            string state=RetailShift.IsTradingAt(hour*60f) ? "OPEN" : "CLOSED";
            foreach(var sign in tradingSigns) if(sign.text!=state) sign.text=state;
            if (hourHand!=null) hourHand.localRotation=Quaternion.Euler(0f,0f,-hour*30f);
            if (minuteHand!=null) minuteHand.localRotation=Quaternion.Euler(0f,0f,-hour*360f);
            float angle=(hour-6f)*Mathf.PI/12f;
            float altitude=Mathf.Sin(angle);
            float day=Mathf.SmoothStep(0f,1f,Mathf.InverseLerp(-.10f,.38f,altitude));
            float high=Mathf.SmoothStep(0f,1f,Mathf.InverseLerp(.12f,.82f,altitude));
            Vector3 source=new Vector3(-Mathf.Cos(angle), Mathf.Max(.12f,Mathf.Abs(altitude)), -.64f);
            sun.transform.rotation=Quaternion.LookRotation(-source.normalized,Vector3.up);
            sun.intensity=Mathf.Lerp(.16f,Mathf.Lerp(.70f,1.08f,high),day);
            sun.color=Color.Lerp(Hex("97ACCC"),Color.Lerp(morning,noon,high),day);
            RenderSettings.ambientSkyColor=Color.Lerp(Hex("354660"),Hex("AEBCC0"),day);
            RenderSettings.ambientEquatorColor=Color.Lerp(Hex("293644"),Hex("9C9B8F"),day);
            RenderSettings.ambientGroundColor=Color.Lerp(Hex("252827"),Hex("88816E"),day);
            RenderSettings.fogColor=Color.Lerp(Hex("24364B"),Color.Lerp(Hex("D7A888"),Hex("ADBFCA"),high),day);
            if(sky!=null)
            {
                sky.SetFloat("_Exposure",Mathf.Lerp(.16f,1.0f,day));
                sky.SetColor("_SkyTint",Color.Lerp(Hex("7385A4"),Hex("B7C3C9"),day));
            }
            foreach(var fixture in shopLights) fixture.intensity=Mathf.Lerp(2.35f,1.65f,day);
        }

        void AddTraffic(float x, float z, float speed)
        {
            var car=ShopModels.Car(transform);
            car.name=speed>0 ? "Eastbound traffic" : "Westbound traffic";
            car.transform.localPosition=new Vector3(x,-.116f,z);
            car.transform.localRotation=Quaternion.Euler(0,speed>0 ? -90f : 90f,0);
            var body=car.AddComponent<Rigidbody>();
            body.isKinematic=true;
            body.interpolation=RigidbodyInterpolation.Interpolate;
            var collider=car.AddComponent<BoxCollider>();
            collider.center=new Vector3(0,.67f,0);
            collider.size=new Vector3(1.56f,1.18f,3.75f);
            traffic.Add(new TrafficCar{body=body,speed=speed});
        }

        void FixedUpdate()
        {
            foreach(var car in traffic)
            {
                Vector3 local=transform.InverseTransformPoint(car.body.position);
                local.x+=car.speed*Time.fixedDeltaTime;
                if(Mathf.Abs(local.x)>StreetEnd)
                {
                    local.x=Mathf.Repeat(local.x+StreetEnd,StreetEnd*2f)-StreetEnd;
                    car.body.position=transform.TransformPoint(local);
                }
                else car.body.MovePosition(transform.TransformPoint(local));
            }
        }

        void OnDestroy()
        {
            Font.textureRebuilt -= RefreshSignAtlas;
            if(RenderSettings.skybox==sky) RenderSettings.skybox=null;
            foreach(var value in owned) if(value!=null) Destroy(value);
        }
    }
}
