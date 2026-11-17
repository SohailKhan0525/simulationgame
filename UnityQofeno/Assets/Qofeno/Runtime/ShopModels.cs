using System;
using System.Collections.Generic;
using UnityEngine;

namespace Qofeno
{
    /// <summary>Harbor Market fittings, packaging, customer and street estate. Units are metres.
    /// Every instance of a design shares one mesh and one opaque print-atlas material.</summary>
    public static partial class ShopModels
    {
        // Fittings face local -Z. Product origins rest on their supporting surface.
        public static readonly Vector3 BeltSpot = new Vector3(-0.63f, 0.905f, 0f);
        public static readonly Vector3 ScannerSpot = new Vector3(0.18f, 0.921f, -0.04f);
        private enum BodyPart { All, Torso, LeftThigh, RightThigh, LeftShin, RightShin, LeftArm, RightArm }
        private enum Design { Shelf, Tea, Cocoa, Soap, Checkout, Carton, Customer, Car }
        private enum Ink { Milk, Bone, Flax, Honey, Brick, Jam, Pine, Sage, Lake, Mist, Navy, Slate, Steel, Pearl, Coal, Rubber, Skin, Hair, Denim, Leather, Glass, Lamp, Mint, Orange }
        private static readonly Mesh[] Meshes = new Mesh[8];
        private static Material material;
        private static Material surfaceTemplate;

        internal static Material CreateSurfaceMaterial(string label)
        {
            if (!surfaceTemplate) surfaceTemplate = Resources.Load<Material>("MarketSurface");
            if (!surfaceTemplate)
                throw new InvalidOperationException("The MarketSurface material is missing from Resources.");
            return new Material(surfaceTemplate) { name = label };
        }

        public static GameObject Shelf(Transform parent) => Instance(Design.Shelf, parent);
        public static GameObject Checkout(Transform parent) => Instance(Design.Checkout, parent);
        public static GameObject Carton(Transform parent) => Instance(Design.Carton, parent);
        public static GameObject Customer(Transform parent) => Instance(Design.Customer, parent);
        public static GameObject Car(Transform parent) => Instance(Design.Car, parent);

        public static GameObject Product(Transform parent, int sku)
        {
            if (sku >= RetailShift.BaseSkuCount) return CoastalProduct(parent, sku);
            if (sku < 0 || sku > 2) throw new ArgumentOutOfRangeException(nameof(sku));
            return Instance((Design)((int)Design.Tea + sku), parent);
        }

        /// <summary>Slots 0-5 hold tea, 6-11 cocoa and 12-17 soap, left to right.</summary>
        public static Vector3 ShelfSlot(int slot)
        {
            if (slot < 0 || slot >= 18) throw new ArgumentOutOfRangeException(nameof(slot));
            return new Vector3(-0.68f + (slot % 6) * 0.272f, 0.18f + (slot / 6) * 0.47f, -0.095f);
        }

        private static GameObject Instance(Design design, Transform parent)
        {
            if (!material) material = PrintAtlas.Material();
            if (!Meshes[(int)design])
            {
                var mesh = new Builder();
                switch (design)
                {
                    case Design.Shelf: BuildShelf(mesh); break;
                    case Design.Tea: BuildTea(mesh); break;
                    case Design.Cocoa: BuildCocoa(mesh); break;
                    case Design.Soap: BuildSoap(mesh); break;
                    case Design.Checkout: BuildCheckout(mesh); break;
                    case Design.Carton: BuildCarton(mesh); break;
                    case Design.Customer: BuildCustomer(mesh); break;
                    case Design.Car: BuildCar(mesh); break;
                }
                Meshes[(int)design] = mesh.Finish("Harbor Market " + design);
            }
            var instance = new GameObject(design.ToString());
            instance.transform.SetParent(parent, false);
            instance.AddComponent<MeshFilter>().sharedMesh = Meshes[(int)design];
            instance.AddComponent<MeshRenderer>().sharedMaterial = material;
            return instance;
        }

        private static Vector3 V(float x, float y, float z) => new Vector3(x, y, z);

        private static void BuildShelf(Builder m)
        {
            // Enameled uprights, slotted backing, shelf-edge rails and separate paper price tickets.
            m.Box(V(0,.08f,0), V(1.76f,.16f,.54f), Ink.Pine,.034f);
            m.Box(V(0,.91f,.239f), V(1.66f,1.54f,.035f), Ink.Bone,.012f);
            foreach (float x in new[]{-.85f,.85f})
            {
                m.Box(V(x,.87f,.215f),V(.052f,1.74f,.09f),Ink.Pine,.01f);
                for (int j=0;j<12;j++) m.Box(V(x,.28f+.103f*j,.166f),V(.018f,.038f,.004f),Ink.Navy);
            }
            for (int row=0;row<3;row++)
            {
                float y=ShelfSlot(row*6).y;
                m.Box(V(0,y-.019f,-.006f),V(1.72f,.038f,.53f),Ink.Bone,.014f);
                m.Box(V(0,y-.03f,-.272f),V(1.73f,.057f,.028f),Ink.Pine,.009f);
                m.Box(V(-.49f,y-.036f,-.291f),V(.55f,.095f,.009f),Ink.Bone,.003f);
            }
            m.Box(V(0,1.63f,.181f),V(1.76f,.18f,.12f),Ink.Pine,.024f);
            m.Front(V(0,1.63f,.119f),1.05f,.131f,PrintAtlas.Header);
        }

        private static void BuildTea(Builder m)
        {
            // Tapered folded box with a narrow paper seam and a gold end flap.
            m.Box(V(0,.104f,0),V(.153f,.208f,.079f),Ink.Pine,.005f);
            m.Box(V(0,.208f,0),V(.149f,.006f,.076f),Ink.Honey,.002f);
            m.Front(V(0,.105f,-.0403f),.145f,.196f,PrintAtlas.Faces[0]);
            m.Box(V(.073f,.106f,.033f),V(.007f,.188f,.01f),Ink.Sage);
        }

        private static void BuildCocoa(Builder m)
        {
            m.Cylinder(V(0,.006f,0),.081f,.081f,.012f,Ink.Steel,20);
            m.Cylinder(V(0,.094f,0),.079f,.079f,.17f,Ink.Jam,24);
            m.Cylinder(V(0,.178f,0),.081f,.081f,.012f,Ink.Steel,24);
            m.Cylinder(V(0,.187f,0),.0825f,.0825f,.015f,Ink.Honey,24);
            m.Cylinder(V(0,.196f,0),.074f,.074f,.004f,Ink.Bone,24);
            // Paper conforms to the cylindrical tin rather than floating on a rectangular plaque.
            m.Sleeve(.0796f,.019f,.17f,69f,PrintAtlas.Faces[1],14);
        }

        private static void BuildSoap(Builder m)
        {
            m.Box(V(0,.06f,0),V(.170f,.12f,.072f),Ink.Mist,.013f);
            m.Box(V(0,.06f,0),V(.095f,.121f,.073f),Ink.Milk,.005f);
            m.Front(V(0,.059f,-.037f),.135f,.094f,PrintAtlas.SoapFront);
        }

        private static void BuildCarton(Builder m)
        {
            m.Box(V(0,.17f,0),V(.47f,.34f,.35f),Ink.Flax,.009f);
            m.Box(V(0,.341f,0),V(.079f,.004f,.348f),Ink.Honey,.001f);
            m.Box(V(0,.281f,-.176f),V(.079f,.119f,.003f),Ink.Honey);
            m.Front(V(-.102f,.161f,-.1764f),.183f,.107f,PrintAtlas.Carton);
            m.Box(V(.141f,.075f,-.176f),V(.133f,.043f,.004f),Ink.Milk,.002f);
            for(int i=0;i<16;i++)
                m.Box(V(.080f+i*.0071f,.075f,-.1786f),V(i%3==0?.005f:.002f,.030f,.001f),Ink.Navy);
        }

        private static void BuildCheckout(Builder m)
        {
            // Customer side faces -Z. Staff can reach the inset scanner, display and card reader.
            m.Box(V(0,.05f,.01f),V(2.18f,.10f,.66f),Ink.Coal,.035f);
            m.Box(V(0,.467f,0),V(2.28f,.75f,.75f),Ink.Pine,.046f);
            m.Box(V(0,.53f,-.372f),V(2.15f,.52f,.027f),Ink.Sage,.021f);
            m.Box(V(0,.54f,-.391f),V(2.05f,.41f,.016f),Ink.Pine,.014f);
            m.Front(V(.70f,.54f,-.401f),.48f,.062f,PrintAtlas.Header);
            m.Box(V(0,.853f,0),V(2.36f,.074f,.84f),Ink.Steel,.052f);
            m.Box(V(-.585f,.894f,0),V(1.025f,.022f,.619f),Ink.Rubber,.037f);
            foreach(float z in new[]{-.324f,.324f})
                m.Box(V(-.58f,.902f,z),V(1.085f,.038f,.025f),Ink.Pearl,.01f);
            for(int i=0;i<5;i++)
                m.Box(V(-1.037f,.9055f,-.19f+i*.093f),V(.018f,.002f,.051f),Ink.Slate,.001f);
            m.Box(V(.18f,.901f,-.04f),V(.40f,.038f,.39f),Ink.Coal,.021f);
            m.Box(V(.18f,.92f,-.04f),V(.291f,.002f,.242f),Ink.Glass,.002f);
            m.Box(V(.18f,.9215f,-.04f),V(.222f,.001f,.006f),Ink.Brick);
            m.Box(V(.51f,.907f,.20f),V(.21f,.044f,.174f),Ink.Coal,.016f);
            m.Box(V(.51f,1.091f,.20f),V(.064f,.34f,.066f),Ink.Slate,.009f);
            m.Box(V(.51f,1.278f,.16f),V(.50f,.324f,.070f),Ink.Coal,.018f);
            m.Front(V(.51f,1.28f,.123f),.457f,.281f,PrintAtlas.Till);
            m.Box(V(.816f,.923f,-.161f),V(.148f,.063f,.244f),Ink.Slate,.015f);
            m.Box(V(.816f,.957f,-.102f),V(.114f,.008f,.076f),Ink.Mist,.003f);
            for(int y=0;y<3;y++)
                for(int x=0;x<3;x++)
                    m.Box(V(.774f+x*.041f,.958f,-.170f-y*.035f),V(.030f,.012f,.022f),
                        y==2 && x==2?Ink.Mint:Ink.Pearl,.003f);
            m.Box(V(.957f,.930f,.147f),V(.178f,.095f,.181f),Ink.Coal,.014f);
            m.Box(V(.957f,.979f,.134f),V(.124f,.005f,.013f),Ink.Rubber);
            m.Box(V(.957f,.984f,.116f),V(.095f,.004f,.052f),Ink.Milk);
        }

        private static void BuildCustomer(Builder m, int appearance = 0)
        {
            bool staff = appearance == 3;
            Ink jacket = staff ? Ink.Bone : appearance == 1 ? Ink.Jam : appearance == 2 ? Ink.Sage : Ink.Navy;
            Ink trousers = staff ? Ink.Slate : appearance == 2 ? Ink.Leather : Ink.Denim;
            Ink skin = appearance == 1 ? Ink.Leather : Ink.Skin;
            // Wool dock jacket, ribbed cuffs, straight denim and an ochre watch cap.
            for(int s=-1;s<=1;s+=2)
            {
                m.Part(s<0 ? BodyPart.LeftShin : BodyPart.RightShin);
                m.Box(V(s*.113f,.076f,-.039f),V(.147f,.15f,.286f),Ink.Leather,.031f);
                m.Box(V(s*.113f,.021f,-.040f),V(.153f,.042f,.294f),Ink.Rubber,.012f);
                m.Taper(V(s*.107f,.13f,.002f),.065f,.078f,V(s*.106f,.462f,0),.081f,.09f,trousers);
                m.Part(s<0 ? BodyPart.LeftThigh : BodyPart.RightThigh);
                m.Taper(V(s*.106f,.451f,0),.081f,.09f,V(s*.105f,.82f,0),.096f,.105f,trousers);
                m.Part(s<0 ? BodyPart.LeftArm : BodyPart.RightArm);
                m.Taper(V(s*.213f,1.321f,.006f),.081f,.087f,V(s*.259f,1.03f,-.024f),.067f,.07f,jacket);
                m.Taper(V(s*.259f,1.035f,-.024f),.067f,.07f,V(s*.258f,.867f,-.07f),.052f,.051f,jacket);
                m.Taper(V(s*.258f,.908f,-.061f),.058f,.06f,V(s*.258f,.853f,-.07f),.05f,.056f,Ink.Slate);
                m.Taper(V(s*.258f,.854f,-.07f),.046f,.048f,V(s*.256f,.776f,-.084f),.037f,.038f,skin);
            }
            m.Part(BodyPart.Torso);
            m.Taper(V(0,.733f,0),.172f,.11f,V(0,.91f,0),.176f,.119f,trousers);
            m.Taper(V(0,.81f,-.002f),.183f,.124f,V(0,1.24f,0),.213f,.139f,jacket);
            m.Taper(V(0,1.238f,0),.213f,.139f,V(0,1.362f,0),.151f,.111f,jacket);
            m.Box(V(0,1.076f,-.125f),V(.014f,.43f,.014f),Ink.Slate,.004f);
            m.Box(V(-.105f,1.18f,-.127f),V(.097f,.070f,.009f),Ink.Slate,.007f);
            m.Cylinder(V(0,1.378f,-.015f),.065f,.065f,.105f,skin,10);
            m.Cylinder(V(0,1.353f,-.011f),.091f,.091f,.040f,Ink.Bone,10);
            m.Taper(V(-.082f,1.329f,-.071f),.043f,.026f,V(-.034f,1.275f,-.124f),.021f,.017f,Ink.Slate);
            m.Taper(V(.082f,1.329f,-.071f),.043f,.026f,V(.034f,1.275f,-.124f),.021f,.017f,Ink.Slate);
            m.Taper(V(0,1.397f,-.027f),.064f,.077f,V(0,1.475f,-.019f),.092f,.10f,skin);
            m.Taper(V(0,1.473f,-.019f),.092f,.10f,V(0,1.602f,-.014f),.096f,.099f,skin);
            m.Box(V(0,1.491f,-.117f),V(.037f,.046f,.032f),skin,.011f);
            foreach(float x in new[]{-.043f,.043f})
            {
                m.Box(V(x,1.535f,-.114f),V(.025f,.009f,.007f),Ink.Hair,.001f);
                m.Box(V(x,1.552f,-.112f),V(.031f,.008f,.008f),Ink.Hair,.002f);
                m.Cylinder(V(x*2.14f,1.50f,-.007f),.014f,.023f,.042f,skin,8);
            }
            m.Box(V(0,1.455f,-.113f),V(.031f,.005f,.003f),Ink.Leather,.001f);
            if (staff)
            {
                // Woven bib, brass snaps, waist tie, patch pockets and a short-billed shop cap.
                m.Taper(V(0,.685f,-.118f),.169f,.025f,V(0,1.22f,-.131f),.123f,.018f,Ink.Pine);
                foreach (float x in new[] {-.095f,.095f})
                {
                    m.Taper(V(x,1.209f,-.137f),.018f,.013f,V(x,1.328f,-.108f),.016f,.012f,Ink.Pine);
                    m.Box(V(x,1.194f,-.156f),V(.015f,.015f,.005f),Ink.Honey);
                }
                m.Box(V(0,.92f,-.147f),V(.34f,.032f,.013f),Ink.Sage,.004f);
                m.Box(V(.068f,.819f,-.150f),V(.104f,.098f,.009f),Ink.Sage,.004f);
                m.Box(V(-.056f,1.134f,-.151f),V(.067f,.030f,.008f),Ink.Bone,.003f);
                m.Cylinder(V(0,1.604f,-.004f),.111f,.111f,.089f,Ink.Pine,16);
                m.Box(V(0,1.577f,-.096f),V(.18f,.015f,.116f),Ink.Sage,.026f);
            }
            else if (appearance == 1)
            {
                m.Cylinder(V(0,1.59f,-.002f),.104f,.109f,.086f,Ink.Hair,12);
                m.Taper(V(.005f,1.43f,.097f),.062f,.061f,V(.005f,1.59f,.083f),.095f,.079f,Ink.Hair);
                m.Cylinder(V(0,1.392f,-.003f),.104f,.10f,.067f,Ink.Honey,14);
                m.Box(V(.084f,1.266f,-.129f),V(.057f,.196f,.015f),Ink.Honey,.009f);
            }
            else
            {
                Ink band = appearance == 2 ? Ink.Mist : Ink.Orange;
                Ink crown = appearance == 2 ? Ink.Slate : Ink.Brick;
                m.Cylinder(V(0,1.595f,-.014f),.106f,.112f,.061f,band,12);
                m.Taper(V(0,1.612f,-.01f),.102f,.108f,V(-.012f,1.688f,.008f),.067f,.065f,crown);
                m.Cylinder(V(-.012f,1.687f,.008f),.067f,.065f,.009f,crown,12);
            }
        }

        private static void BuildCar(Builder m)
        {
            // Parked quay estate, nose towards -Z. Wheels use local X axles.
            m.Box(V(0,.35f,0),V(1.49f,.23f,3.69f),Ink.Coal,.079f);
            m.Box(V(0,.575f,0),V(1.69f,.38f,3.81f),Ink.Sage,.114f);
            m.Box(V(0,.795f,-1.177f),V(1.61f,.119f,1.34f),Ink.Sage,.046f);
            m.Taper(V(0,.747f,.30f),.797f,1.427f,V(0,1.324f,.46f),.649f,1.029f,Ink.Glass);
            m.Box(V(0,1.344f,.46f),V(1.339f,.077f,2.12f),Ink.Sage,.035f);
            foreach(float s in new[]{-1f,1f})
            {
                m.Taper(V(s*.799f,.754f,.214f),.016f,.049f,V(s*.650f,1.323f,.28f),.018f,.050f,Ink.Slate);
                m.Taper(V(s*.799f,.754f,1.12f),.017f,.032f,V(s*.650f,1.323f,1.06f),.018f,.034f,Ink.Sage);
                m.Box(V(s*.852f,.688f,0),V(.029f,.047f,3.257f),Ink.Slate,.012f);
                foreach(float z in new[]{-.09f,.89f})
                    m.Box(V(s*.855f,.731f,z),V(.034f,.04f,.126f),Ink.Coal,.009f);
                m.Box(V(s*.86f,.953f,-.743f),V(.242f,.146f,.178f),Ink.Sage,.033f);
                m.Box(V(s*.503f,1.413f,.435f),V(.05f,.041f,1.65f),Ink.Slate,.015f);
                foreach(float z in new[]{-1.23f,1.225f})
                {
                    m.WheelArch(V(s*.848f,.304f,z),s,.304f,.337f);
                    m.CylinderX(V(s*.777f,.304f,z),.302f,.159f,Ink.Rubber,16);
                    m.CylinderX(V(s*.860f,.304f,z),.180f,.019f,Ink.Steel,16);
                    m.CylinderX(V(s*.873f,.304f,z),.106f,.015f,Ink.Slate,10);
                    m.CylinderX(V(s*.882f,.304f,z),.045f,.012f,Ink.Pearl,8);
                }
                m.Box(V(s*.602f,.637f,-1.887f),V(.329f,.112f,.056f),Ink.Lamp,.017f);
                m.Box(V(s*.608f,.632f,1.889f),V(.30f,.16f,.054f),Ink.Brick,.019f);
            }
            m.Box(V(0,.588f,-1.905f),V(.654f,.16f,.028f),Ink.Navy,.009f);
            for(int i=0;i<3;i++)
                m.Box(V(0,.542f+.043f*i,-1.922f),V(.594f,.009f,.006f),Ink.Slate);
            m.Box(V(0,.42f,-1.909f),V(.411f,.115f,.018f),Ink.Bone,.008f);
            m.Box(V(0,.559f,1.912f),V(.423f,.123f,.016f),Ink.Honey,.007f);
        }

        private static class PrintAtlas
        {
            // Input rectangles are in image-editor coordinates (top left). Unity UVs start bottom left.
            public static readonly Rect[] Faces = { Region(8,8,240,300), Region(264,8,240,300), Region(520,8,240,300) };
            public static readonly Rect[] Tickets = { Region(8,342,192,58), Region(216,342,192,58), Region(424,342,192,58) };
            public static readonly Rect SoapFront = Region(628,316,300,174);
            public static readonly Rect Header = Region(8,424,600,70);
            public static readonly Rect Till = Region(8,512,484,294);
            public static readonly Rect Carton = Region(520,512,286,164);
            private static Rect Region(int x,int y,int width,int height)
            {
                return new Rect((x+.5f)/1024f,(1024-y-height+.5f)/1024f,(width-1)/1024f,(height-1)/1024f);
            }
            public static Vector2 Swatch(Ink ink)
            {
                int i=(int)ink;
                return new Vector2((32f+i%12*80f)/1024f,1-(872f+i/12*64f)/1024f);
            }
            public static Material Material()
            {
                var mat = CreateSurfaceMaterial("Harbor enamel and paper");
                mat.mainTexture = Resources.Load<Texture2D>("ShopModels/harbor-prints");
                if(mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness",.20f);
                return mat;
            }
        }

        private sealed class Builder
        {
            private readonly BodyPart filter;
            private readonly Vector3 origin;
            private BodyPart activePart;
            public Builder(BodyPart filter=BodyPart.All,Vector3 origin=default)
            {
                this.filter=filter; this.origin=origin;
            }
            public void Part(BodyPart part) { activePart=part; }
            private readonly List<Vector3> v=new List<Vector3>();
            private readonly List<Vector3> normals=new List<Vector3>();
            private readonly List<Vector2> uv=new List<Vector2>();
            private readonly List<int> triangles=new List<int>();
            public Mesh Finish(string name)
            {
                var mesh=new Mesh { name=name };
                mesh.SetVertices(v); mesh.SetNormals(normals); mesh.SetUVs(0,uv); mesh.SetTriangles(triangles,0);
                mesh.RecalculateBounds();
                return mesh;
            }
            private void Surface(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 outward,
                                 Vector2 ta,Vector2 tb,Vector2 tc,Vector2 td,bool triangle=false)
            {
                if(filter!=BodyPart.All && filter!=activePart) return;
                var normal=Vector3.Cross(b-a,c-a).normalized;
                bool reverse=Vector3.Dot(normal,outward)<0;
                if(reverse) normal=-normal;
                int n=v.Count;
                v.Add(a-origin); v.Add(b-origin); v.Add(c-origin); if(!triangle)v.Add(d-origin);
                normals.Add(normal); normals.Add(normal); normals.Add(normal); if(!triangle)normals.Add(normal);
                uv.Add(ta); uv.Add(tb); uv.Add(tc); if(!triangle)uv.Add(td);
                triangles.Add(n); triangles.Add(n+(reverse?2:1)); triangles.Add(n+(reverse?1:2));
                if(!triangle) { triangles.Add(n); triangles.Add(n+(reverse?3:2)); triangles.Add(n+(reverse?2:3)); }
            }
            public void Front(Vector3 center,float w,float h,Rect print)
            {
                var x = V(w*.5f,0,0); var y=V(0,h*.5f,0);
                Surface(center-x-y,center+x-y,center+x+y,center-x+y,Vector3.back,
                    new Vector2(print.xMin,print.yMin),new Vector2(print.xMax,print.yMin),
                    new Vector2(print.xMax,print.yMax),new Vector2(print.xMin,print.yMax));
            }
            public void Sleeve(float radius,float bottom,float top,float degrees,Rect print,int count)
            {
                for(int i=0;i<count;i++)
                {
                    float t0=(float)i/count,t1=(float)(i+1)/count;
                    float a=(2*t0-1)*degrees*Mathf.Deg2Rad,b=(2*t1-1)*degrees*Mathf.Deg2Rad;
                    var p=V(radius*Mathf.Sin(a),bottom,-radius*Mathf.Cos(a));
                    var q=V(radius*Mathf.Sin(b),bottom,-radius*Mathf.Cos(b));
                    var h=V(0,top-bottom,0);
                    float u0=print.xMin+print.width*t0,u1=print.xMin+print.width*t1;
                    Surface(p,q,q+h,p+h,V(p.x+q.x,0,p.z+q.z),
                        new Vector2(u0,print.yMin),new Vector2(u1,print.yMin),new Vector2(u1,print.yMax),new Vector2(u0,print.yMax));
                }
            }
            private static Vector3[] Corners(Vector3 c,float x,float z,float cut)
            {
                return new[]{c+V(-x+cut,0,-z),c+V(x-cut,0,-z),c+V(x,0,-z+cut),c+V(x,0,z-cut),
                    c+V(x-cut,0,z),c+V(-x+cut,0,z),c+V(-x,0,z-cut),c+V(-x,0,-z+cut)};
            }
            private void Side(Vector3[] bottom,Vector3[] top,Ink ink,Vector3 inside)
            {
                var t=PrintAtlas.Swatch(ink);
                for(int i=0;i<bottom.Length;i++)
                {
                    int j=(i+1)%bottom.Length;
                    Vector3 a=bottom[i],b=bottom[j],c=top[j],d=top[i];
                    Surface(a,b,c,d,(a+b+c+d)*.25f-inside,t,t,t,t);
                }
            }
            private void Cap(Vector3[] ring,Vector3 center,Vector3 outward,Ink ink)
            {
                var t=PrintAtlas.Swatch(ink);
                for(int i=0;i<ring.Length;i++)
                    Surface(center,ring[i],ring[(i+1)%ring.Length],center,outward,t,t,t,t,true);
            }
            public void Box(Vector3 c,Vector3 size,Ink ink,float bevel=0)
            {
                float x=size.x*.5f,y=size.y*.5f,z=size.z*.5f;
                // Short, square-edged details use exactly six faces.
                if(bevel<=0)
                {
                    var bottom=new[]{c+V(-x,-y,-z),c+V(x,-y,-z),c+V(x,-y,z),c+V(-x,-y,z)};
                    var top=new[]{c+V(-x,y,-z),c+V(x,y,-z),c+V(x,y,z),c+V(-x,y,z)};
                    var t=PrintAtlas.Swatch(ink);
                    Side(bottom,top,ink,c);
                    Surface(bottom[0],bottom[1],bottom[2],bottom[3],Vector3.down,t,t,t,t);
                    Surface(top[0],top[1],top[2],top[3],Vector3.up,t,t,t,t);
                    return;
                }
                float cut=Mathf.Min(bevel,Mathf.Min(x,z)*.55f);
                float shoulder=Mathf.Min(cut*.26f,y*.4f);
                var lower=Corners(c+V(0,-y,0),x-shoulder,z-shoulder,cut*.65f);
                var lo=Corners(c+V(0,-y+shoulder,0),x,z,cut);
                var hi=Corners(c+V(0,y-shoulder,0),x,z,cut);
                var upper=Corners(c+V(0,y,0),x-shoulder,z-shoulder,cut*.65f);
                Side(lower,lo,ink,c); Side(lo,hi,ink,c); Side(hi,upper,ink,c);
                Cap(lower,c+V(0,-y,0),Vector3.down,ink); Cap(upper,c+V(0,y,0),Vector3.up,ink);
            }
            public void Taper(Vector3 from,float x0,float z0,Vector3 to,float x1,float z1,Ink ink)
            {
                var a=Corners(from,x0,z0,Mathf.Min(x0,z0)*.39f);
                var b=Corners(to,x1,z1,Mathf.Min(x1,z1)*.39f);
                Side(a,b,ink,(from+to)*.5f);
                var dy=to.y>=from.y?Vector3.up:Vector3.down;
                Cap(a,from,-dy,ink); Cap(b,to,dy,ink);
            }
            public void WheelArch(Vector3 center,float side,float inner,float outer)
            {
                var t=PrintAtlas.Swatch(Ink.Slate);
                for(int i=0;i<10;i++)
                {
                    float a=i*Mathf.PI/10,b=(i+1)*Mathf.PI/10;
                    var da=V(0,Mathf.Sin(a),Mathf.Cos(a));
                    var db=V(0,Mathf.Sin(b),Mathf.Cos(b));
                    Surface(center+da*inner,center+db*inner,center+db*outer,center+da*outer,
                        Vector3.right*side,t,t,t,t);
                }
            }
            public void Cylinder(Vector3 c,float rx,float rz,float height,Ink ink,int divisions)
                => Drum(c,rx,rz,height,ink,divisions,false);
            public void CylinderX(Vector3 c,float r,float width,Ink ink,int divisions)
                => Drum(c,r,r,width,ink,divisions,true);
            private void Drum(Vector3 c,float rx,float rz,float length,Ink ink,int count,bool axle)
            {
                var a=new Vector3[count]; var b=new Vector3[count];
                Vector3 axis=axle?Vector3.right:Vector3.up;
                for(int i=0;i<count;i++)
                {
                    float angle=2*Mathf.PI*i/count;
                    float radialX=Mathf.Sin(angle)*rx,radialZ=Mathf.Cos(angle)*rz;
                    var pos=c+(axle?V(0,radialX,radialZ):V(radialX,0,radialZ));
                    a[i]=pos-axis*(length*.5f); b[i]=pos+axis*(length*.5f);
                }
                Side(a,b,ink,c); Cap(a,c-axis*(length*.5f),-axis,ink); Cap(b,c+axis*(length*.5f),axis,ink);
            }
        }
    }
}
